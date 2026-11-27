#!/usr/bin/env bash
# eval-tmpdir-guard: claude plugin eval denies writes under /tmp, /var/tmp,
# /dev/shm and /run/shm in its sandbox, and puts its run folder under TMPDIR.
set -u
guard="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/eval-tmpdir-guard.sh"
fail=0
scratch=$(mktemp -d "${XDG_RUNTIME_DIR:-$HOME}/eval-tmpdir-test.XXXXXX")
trap 'rm -rf "$scratch"' EXIT
mkdir -p "$scratch/good"
ln -s /tmp "$scratch/to-tmp"
# code <TMPDIR or "unset"> <command>. It runs from /tmp, so a TMPDIR left
# unexpanded resolves under /tmp and is refused.
code() {
  local t=$1 c=$2
  if [ "$t" = unset ]; then
    jq -nc --arg c "$c" '{tool_input:{command:$c}}' | (cd /tmp && env -u TMPDIR XDG_RUNTIME_DIR="$scratch/good" bash "$guard") >/dev/null 2>&1; echo $?
  else
    jq -nc --arg c "$c" '{tool_input:{command:$c}}' | (cd /tmp && TMPDIR="$t" XDG_RUNTIME_DIR="$scratch/good" bash "$guard") >/dev/null 2>&1; echo $?
  fi
}
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got $3, want $2"; fail=1; fi; }
ev='claude plugin eval plugins/x --case y --scaffold'
check "the snag: TMPDIR unset is refused" 2 "$(code unset "$ev")"
check "TMPDIR=/tmp is refused" 2 "$(code /tmp "$ev")"
check "TMPDIR under /var/tmp is refused" 2 "$(code /var/tmp/x "$ev")"
check "TMPDIR under /dev/shm is refused" 2 "$(code /dev/shm/x "$ev")"
check "TMPDIR under /run/shm is refused" 2 "$(code /run/shm "$ev")"
check "a symlink into /tmp is refused" 2 "$(code "$scratch/to-tmp/x" "$ev")"
check "an inline TMPDIR=/tmp is refused" 2 "$(code "$scratch/good" "TMPDIR=/tmp $ev")"
check "a quoted inline TMPDIR=/tmp is refused" 2 "$(code "$scratch/good" "TMPDIR=\"/tmp\" $ev")"
check "a TMPDIR= after the eval is its argument, not its TMPDIR" 2 "$(code /tmp "$ev TMPDIR=$scratch/good")"
check "an inline braced XDG_RUNTIME_DIR TMPDIR runs" 0 "$(code /tmp "TMPDIR=\${XDG_RUNTIME_DIR} $ev")"
check "an empty inline TMPDIR is refused" 2 "$(code "$scratch/good" "TMPDIR= $ev")"
check "a TMPDIR= for an earlier command is not the eval's" 0 "$(code "$scratch/good" "TMPDIR=/tmp true; $ev")"
check "a good TMPDIR runs" 0 "$(code "$scratch/good" "$ev")"
check "an inline XDG_RUNTIME_DIR TMPDIR runs" 0 "$(code /tmp "TMPDIR=\"\$XDG_RUNTIME_DIR\" $ev")"
check "an inline good path runs" 0 "$(code /tmp "TMPDIR=$scratch/good $ev")"
check "another command under /tmp runs" 0 "$(code /tmp 'claude plugin validate .')"
check "eval named in a heredoc body is text" 0 "$(code /tmp "$(printf 'cat <<EOF\n%s\nEOF' "$ev")")"
check "bad input passes" 0 "$(echo nope | TMPDIR=/tmp bash "$guard" >/dev/null 2>&1; echo $?)"
exit $fail
