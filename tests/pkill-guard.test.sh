#!/usr/bin/env bash
# pkill-guard reads commands, not text: pkill -f inside a heredoc body runs.
set -u
guard="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/pkill-guard.sh"
fail=0
code() { jq -nc --arg c "$1" '{tool_input:{command:$c}}' | bash "$guard" >/dev/null 2>&1; echo $?; }
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got $3, want $2"; fail=1; fi; }
check "pkill -f in a heredoc body is text" 0 "$(code "$(printf 'cat <<EOF\npkill -f x\nEOF')")"
check "pkill -x runs" 0 "$(code 'pkill -x node')"
check "pkill --full is refused" 2 "$(code 'pkill --full node')"
check "bad input passes" 0 "$(echo nope | bash "$guard" >/dev/null 2>&1; echo $?)"
exit $fail
