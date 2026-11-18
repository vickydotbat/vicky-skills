#!/usr/bin/env bash
# cap.sh <seconds> <memory> -- <command...>: runs one opponent command under a
# time cap and a memory cap, in a process group of its own, and stops only that
# group. Over a cap it prints "finding: over the time cap" or "finding: over
# the memory cap" and exits non-zero. Otherwise it exits as the command did.
set -u
secs=${1:?usage: cap.sh <seconds> <memory> -- <command...>}
mem=${2:?usage: cap.sh <seconds> <memory> -- <command...>}
shift 2
bytes=$(numfmt --from=iec "$mem") || exit 2
err=$(mktemp)
trap 'rm -f "$err"' EXIT # mutant-ok delete: the temporary file is the only effect, and no caller reads it
setsid bash -c 'ulimit -v "$1"; shift; exec "$@"' _ "$((bytes / 1024))" "$@" 2> >(tee "$err" >&2) &
pid=$!
(sleep "$secs"; kill -TERM -- -"$pid" 2>/dev/null; sleep 1; kill -KILL -- -"$pid" 2>/dev/null) &
timer=$!
wait "$pid"
rc=$?
kill "$timer" 2>/dev/null
wait "$timer" 2>/dev/null # mutant-ok delete: the timer is already killed, so waiting on it changes no result
if [ "$rc" -eq 143 ] || [ "$rc" -eq 137 ]; then
  echo "finding: over the time cap of ${secs}s"
  exit 124
fi
if [ "$rc" -ne 0 ] && grep -qiE 'MemoryError|Cannot allocate memory|out of memory|bad_alloc' "$err"; then
  echo "finding: over the memory cap of $mem"
  exit 125
fi
exit "$rc"
