#!/usr/bin/env bash
# shellcheck disable=SC2016 # check() evals its single-quoted condition later
# shellcheck disable=SC2034 # names set here are read inside check()'s eval
# shellcheck disable=SC2329 # helpers are called inside check()'s eval
# repeat-call-hint's decisions beyond its approved examples: one steer per run
# of repeats, sessions apart, stderr counted, the setting off, a missing jq,
# bad input and an unwritable state folder.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
hook="$root/plugins/vicky-skills/scripts/repeat-call-hint.sh"
fx=$(mktemp -d); trap 'chmod -R u+w "$fx"; rm -rf "$fx"' EXIT
export REPEAT_CALL_STATE="$fx/state"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
call() { # call <session> <command> <stdout> [stderr]
  jq -nc --arg s "$1" --arg c "$2" --arg o "$3" --arg e "${4:-}" '{session_id:$s,tool_name:"Bash",tool_input:{command:$c},tool_response:{stdout:$o,stderr:$e}}' |
    CLAUDE_PLUGIN_OPTION_GUARD_REPEAT_CALL="${opt-}" bash "$hook" 2>/dev/null
}
steered() { [ -n "$1" ]; }
for i in 1 2 3; do out=$(call a "x" "same"); done
check "the third repeat steers" 'steered "$out"'
out=$(call a "x" "same"); rc=$?
check "the fourth repeat adds nothing more" '[ $rc = 0 ] && [ -z "$out" ]'
call b "y" "o" >/dev/null; call c "y" "o" >/dev/null; out=$(call b "y" "o")
check "another session's call breaks no run and joins none" '[ -z "$out" ]'
call d "z" "o" "e1" >/dev/null; call d "z" "o" "e2" >/dev/null; out=$(call d "z" "o" "e3")
check "stderr that changes is a changing output" '[ -z "$out" ]'
for i in 1 2 3; do out=$(opt=false call e "x" "same"); rc=$?; done
check "the setting off adds nothing and exits 0" '[ $rc = 0 ] && [ -z "$out" ]'
check "bad input exits 0" '[ "$(echo notjson | bash "$hook" >/dev/null 2>&1; echo $?)" = 0 ]'
check "no jq exits 0" '[ "$(echo "{}" | PATH=/nonexistent "$BASH" "$hook" >/dev/null 2>&1; echo $?)" = 0 ]'
mkdir -p "$fx/ro"; chmod a-w "$fx/ro"
check "an unwritable state folder exits 0" '[ "$(echo "{}" | REPEAT_CALL_STATE="$fx/ro/s" bash "$hook" >/dev/null 2>&1; echo $?)" = 0 ]'
exit $fail
