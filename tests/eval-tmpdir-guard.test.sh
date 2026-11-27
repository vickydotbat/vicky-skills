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
# code <TMPDIR or "unset"> <command>. It runs from a good folder, so a TMPDIR
# the guard leaves unexpanded would resolve to a good path and pass.
code() {
  local t=$1 c=$2
  if [ "$t" = unset ]; then
    jq -nc --arg c "$c" '{tool_input:{command:$c}}' | (cd "$scratch/good" && env -u TMPDIR XDG_RUNTIME_DIR="$scratch/good" bash "$guard") >/dev/null 2>&1; echo $?
  else
    jq -nc --arg c "$c" '{tool_input:{command:$c}}' | (cd "$scratch/good" && TMPDIR="$t" XDG_RUNTIME_DIR="$scratch/good" bash "$guard") >/dev/null 2>&1; echo $?
  fi
}
# msg <TMPDIR> <command>: the refusal's text.
msg() { jq -nc --arg c "$2" '{tool_input:{command:$c}}' | (cd "$scratch/good" && TMPDIR="$1" XDG_RUNTIME_DIR="$scratch/good" bash "$guard") 2>&1; }
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
check "a TMPDIR=/tmp anywhere in an eval command is refused" 2 "$(code "$scratch/good" "TMPDIR=/tmp true; $ev")"
check "a good TMPDIR for an earlier command does not cover the eval" 2 "$(code /tmp "TMPDIR=$scratch/good true; $ev")"
check "an exported good TMPDIR covers the eval" 0 "$(code /tmp "export TMPDIR=$scratch/good; $ev")"
check "an exported TMPDIR=/tmp is refused" 2 "$(code "$scratch/good" "export TMPDIR=/tmp; $ev")"
check "a bare TMPDIR=/tmp statement is refused" 2 "$(code "$scratch/good" "TMPDIR=/tmp; $ev")"
check "an inline TMPDIR on a continued line is refused" 2 "$(code "$scratch/good" "$(printf 'TMPDIR=/tmp \\\n %s' "$ev")")"
check "a global flag before plugin is still the eval" 2 "$(code /tmp 'claude --debug plugin eval x')"
check "an absolute claude path is still the eval" 2 "$(code /tmp '/usr/bin/claude plugin eval x')"
check "a quoted claude is still the eval" 2 "$(code /tmp '"claude" plugin eval x')"
check "a second eval with a bad TMPDIR is refused" 2 "$(code /tmp "TMPDIR=$scratch/good $ev; TMPDIR=/tmp $ev")"
check "a commit message naming the eval is text" 0 "$(code /tmp 'git commit -m "docs: claude plugin eval needs TMPDIR"')"
check "a TMPDIR the guard cannot expand is refused" 2 "$(code "$scratch/good" 'TMPDIR=${HOME:-/tmp} claude plugin eval x')"
check "a TMPDIR under the home folder sign is refused" 2 "$(code "$scratch/good" 'TMPDIR=~/../../tmp claude plugin eval x')"
check "a relative TMPDIR is refused" 2 "$(code "$scratch/good" 'cd /tmp && TMPDIR=. claude plugin eval x')"
check "an inline XDG_RUNTIME_DIR subfolder runs" 0 "$(code /tmp "TMPDIR=\$XDG_RUNTIME_DIR/evals $ev")"
check "a good TMPDIR runs" 0 "$(code "$scratch/good" "$ev")"
check "an inline XDG_RUNTIME_DIR TMPDIR runs" 0 "$(code /tmp "TMPDIR=\"\$XDG_RUNTIME_DIR\" $ev")"
check "an inline good path runs" 0 "$(code /tmp "TMPDIR=$scratch/good $ev")"
check "another command under /tmp runs" 0 "$(code /tmp 'claude plugin validate .')"
check "eval named in a heredoc body is text" 0 "$(code /tmp "$(printf 'cat <<EOF\n%s\nEOF' "$ev")")"
mkdir -p "$scratch/nojq"
for t in bash awk gawk grep tr realpath dirname; do ln -s "$(command -v "$t")" "$scratch/nojq/$t"; done
check "a missing jq passes" 0 "$(printf '{"tool_input":{"command":"%s"}}' "$ev" | env -u TMPDIR PATH="$scratch/nojq" "$scratch/nojq/bash" "$guard" >/dev/null 2>&1; echo $?)"
check "unset TMPDIR before the eval is refused" 2 "$(code "$scratch/good" "unset TMPDIR; $ev")"
check "env -u TMPDIR on the eval is refused" 2 "$(code "$scratch/good" "env -u TMPDIR $ev")"
check "a bare good TMPDIR does not reach the eval when none is exported" 2 "$(code unset "TMPDIR=$scratch/good; $ev")"
check "a bare good TMPDIR reaches the eval when one is exported" 0 "$(code /tmp "TMPDIR=$scratch/good; $ev")"
check "an export after unset covers the eval" 0 "$(code "$scratch/good" "unset TMPDIR; export TMPDIR=$scratch/good; $ev")"
check "another command with TMPDIR=/tmp runs" 0 "$(code "$scratch/good" 'TMPDIR=/tmp make check')"
check "an unclosed quote reads the command unmasked" 2 "$(code /tmp "echo \"a; $ev")"
m=$(msg /tmp "$ev")
check "a denied TMPDIR names the read-only failure and the steer" yes "$([[ $m == *"read-only file system"* && $m == *'TMPDIR="$XDG_RUNTIME_DIR"'* ]] && echo yes)"
m=$(msg "$scratch/good" "TMPDIR=~/x $ev")
check "an unexpandable TMPDIR says the guard cannot tell" yes "$([[ $m == *"not a literal absolute path"* ]] && echo yes)"
check "bad input passes" 0 "$(echo nope | TMPDIR=/tmp bash "$guard" >/dev/null 2>&1; echo $?)"
exit $fail
