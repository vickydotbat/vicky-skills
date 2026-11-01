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
text() { run "$1" | jq -r '.hookSpecificOutput.additionalContext // empty'; }
check "a GitHub draft is sent to make-it-so" yes "$(text 'git push -u origin x && gh pr create --draft --title T' | grep -q "Finish it now with the make-it-so skill" && echo yes)"
check "a Gitea WIP pull request is sent to make-it-so" yes "$(text 'tea pr create --title "WIP: summit" </dev/null' | grep -q "make-it-so" && echo yes)"
check "tea pulls create counts as tea pr create" yes "$(text 'tea pulls create --title "WIP: x"' | grep -q "make-it-so" && echo yes)"
check "the steer names the gate it may stop at" yes "$(text 'gh pr create --draft' | grep -q "Waits on:" && echo yes)"
check "a ready pull request gets no make-it-so steer" "" "$(text 'gh pr create --title T' | grep -o make-it-so)"
check "a Gitea pull request without WIP gets no steer" "" "$(run 'tea pr create --title summit')"
check "the draft flag in a word gets no steer" "" "$(run 'echo gh pr created --draft')"
check "a push that opens a draft gets the draft steer alone" 1 "$(nudge 'git push -u origin x && gh pr create --draft' | wc -l)"
check "the draft steer exits 0, so Claude Code reads it as a note" 0 "$(run 'gh pr create --draft' >/dev/null; echo $?)"
check "a push still gets the body reminder" yes "$(text 'git push' | grep -q "You pushed" && echo yes)"
exit $fail
