#!/usr/bin/env bash
# cap.sh <seconds> <memory> -- <command...>: runs one opponent command under a
# time cap and a memory cap, and stops only what it started. Over a cap it
# prints "finding: over the time cap" (exit 124) or "finding: over the memory
# cap" (exit 125). Otherwise it exits as the command did, and kills anything
# the command left running.
#
# With a systemd user manager the command runs in a scope of its own: the
# memory cap counts memory used, not address space (a runtime such as .NET
# reserves far more than it uses), and stopping the scope reaches every
# process in it, a setsid grandchild included. Without one (a CI runner),
# it falls back to a process group and ulimit -v. shortcut: the fallback
# misses a grandchild that leaves the group, and needs the command to print
# its memory error.
set -u
secs=${1:?usage: cap.sh <seconds> <memory> -- <command...>}
mem=${2:?usage: cap.sh <seconds> <memory> -- <command...>}
shift 2
[ "${1:-}" = -- ] && shift
bytes=$(numfmt --from=iec "$mem") || exit 2
err=$(mktemp)
trap 'rm -f "$err"' EXIT # mutant-ok delete: the temporary file is the only effect, and no caller reads it
unit=""
if [ -z "${CAP_NO_SCOPE:-}" ] && systemd-run --user --scope -q true 2>/dev/null; then
  unit="cap-$$-$RANDOM"
  systemd-run --user --scope -q --unit="$unit" -p MemoryMax="$bytes" -p MemorySwapMax=0 -- "$@" &
else
  setsid bash -c 'ulimit -v "$1"; shift; exec "$@"' _ "$((bytes / 1024))" "$@" 2> >(tee "$err" >&2) &
fi
pid=$!
sleep "$secs" &
timer=$!
wait -n "$pid" "$timer"
timed_out=0
kill -0 "$pid" 2>/dev/null && timed_out=1
stop() {
  if [ -n "$unit" ]; then
    systemctl --user kill --signal=KILL "$unit.scope" 2>/dev/null
  else
    kill -KILL -- -"$pid" 2>/dev/null
  fi
}
if [ "$timed_out" = 1 ]; then
  if [ -n "$unit" ]; then systemctl --user kill --signal=TERM "$unit.scope" 2>/dev/null; else kill -TERM -- -"$pid" 2>/dev/null; fi
  sleep 1
fi
stop
kill "$timer" 2>/dev/null
wait "$pid" 2>/dev/null
rc=$?
result=""
if [ -n "$unit" ]; then
  result=$(systemctl --user show "$unit.scope" -p Result --value 2>/dev/null) # mutant-ok delete: only a real kill in a scope reads it; mutant runs make none, to spare the desktop, and the plain test run checks the memory cap finding
  systemctl --user reset-failed "$unit.scope" 2>/dev/null # mutant-ok delete: only a real kill in a scope leaves a failed unit; the plain test run checks none is left
fi
if [ "$timed_out" = 1 ]; then
  echo "finding: over the time cap of ${secs}s"
  exit 124
fi
if [ "$result" = oom-kill ] || { [ -z "$unit" ] && [ "$rc" -ne 0 ] && grep -qiE 'MemoryError|Cannot allocate memory|out of memory|bad_alloc' "$err"; }; then
  echo "finding: over the memory cap of $mem"
  exit 125
fi
exit "$rc"
