#!/usr/bin/env bash
# The hook nudges after a git push and stays silent for every other command.
set -u
hook="$(dirname "$0")/../plugins/vicky-skills/scripts/after-push.sh"
fail=0
run() { jq -n --arg c "$1" '{tool_input:{command:$c}}' | "$hook"; }
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got '$3'"; fail=1; fi; }
nudge() { run "$1" | jq -r '.hookSpecificOutput.hookEventName // empty'; }
check "nudges after git push" PostToolUse "$(nudge 'git push origin topic')"
check "nudges after a chained push" PostToolUse "$(nudge 'git fetch && git push --force-with-lease')"
check "silent on git status" "" "$(run 'git status')"
check "silent on git pull" "" "$(run 'git pull --rebase')"
check "silent on a word that holds push" "" "$(run 'echo git pushing')"
exit $fail
