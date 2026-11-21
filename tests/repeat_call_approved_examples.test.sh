#!/usr/bin/env bash
# shellcheck disable=SC2016 # check() evals its single-quoted condition later
# shellcheck disable=SC2034 # names set here are read inside check()'s eval
# approved-spec: the examples approved on the note "LC-3 Three identical calls
# get a steer". repeat-call-hint.sh runs on PostToolUse for Bash, which fires
# for each call inside a REPL script too (LC-AT2).
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
scripts="$root/plugins/vicky-skills/scripts"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
hook="$scripts/repeat-call-hint.sh"
fx=$(mktemp -d); trap 'rm -rf "$fx"' EXIT
export REPEAT_CALL_STATE="$fx/state"
call() { # call <command> <stdout>; returns 127 while the hook is missing
  [ -f "$hook" ] || return 127
  jq -nc --arg c "$1" --arg o "$2" '{hook_event_name:"PostToolUse",session_id:"s1",tool_name:"Bash",tool_input:{command:$c},tool_response:{stdout:$o,stderr:""}}' | bash "$hook" 2>/dev/null
}
steer() { jq -r '.hookSpecificOutput.additionalContext // empty' <<<"$1" 2>/dev/null; }

# Given an agent that ran the same Bash command 3 times in a row
# When the third call returns
# Then the agent reads one line saying it repeated the call, and to change approach or ask
# Given the agent ran the same call 3 times in a row with identical output
# When the third call returns
# Then the agent reads one line saying it repeated the call, and to change approach or ask
call "make test" "boom" >/dev/null; call "make test" "boom" >/dev/null; out=$(call "make test" "boom")
s=$(steer "$out")
check "LC-3 E1 E4 the third identical call gets one steer line" '[ "$(printf "%s\n" "$s" | grep -c .)" = 1 ] && grep -qi "repeated" <<<"$s" && grep -qi "change approach or ask" <<<"$s"'

# Given an agent that ran a command twice, then a different one
# When the third call returns
# Then the agent reads nothing extra
rm -rf "$REPEAT_CALL_STATE"
call "ls" "a" >/dev/null; call "ls" "a" >/dev/null; out=$(call "pwd" "/x"); rc=$?
check "LC-3 E2 twice then a different call adds nothing" '[ $rc = 0 ] && [ -z "$out" ]'

# Given the agent ran the same status call 3 times in a row
# And the output differs between calls, or shows a run still pending
# When the third call returns
# Then the agent reads nothing extra
rm -rf "$REPEAT_CALL_STATE"
call "gh pr checks 5" "pending 1" >/dev/null; call "gh pr checks 5" "pending 2" >/dev/null; out=$(call "gh pr checks 5" "pending 3"); rc=$?
check "LC-3 E3 changing output adds nothing" '[ $rc = 0 ] && [ -z "$out" ]'
rm -rf "$REPEAT_CALL_STATE"
for i in 1 2; do call "gh run view 9" "status: in_progress" >/dev/null; done; out=$(call "gh run view 9" "status: in_progress"); rc=$?
check "LC-3 E3 output showing a run still pending adds nothing" '[ $rc = 0 ] && [ -z "$out" ]'

exit $fail
