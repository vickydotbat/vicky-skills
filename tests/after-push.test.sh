#!/usr/bin/env bash
# The hook nudges after a git push, steers a draft opened in a warp run to\n# make-it-so, hints at it for any other draft, and stays silent otherwise.
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
fx=$(mktemp -d); trap 'rm -rf "$fx"' EXIT
printf '%s\n' '{"type":"user","message":{"content":"<command-name>/vicky-skills:warp</command-name>"}}' > "$fx/warp.jsonl"
printf '%s\n' '{"type":"user","message":{"content":"<command-name>/vicky-skills:do</command-name>"}}' > "$fx/do.jsonl"
text() { jq -n --arg c "$1" --arg t "${2:-}" '{tool_input:{command:$c}, transcript_path:$t}' | "$hook" | jq -r '.hookSpecificOutput.additionalContext // empty'; }
check "a draft in a warp run is sent to make-it-so" yes "$(text 'git push -u origin x && gh pr create --draft --title T' "$fx/warp.jsonl" | grep -q "Finish it now with the make-it-so skill" && echo yes)"
check "the warp steer names the gate it may stop at" yes "$(text 'gh pr create --draft' "$fx/warp.jsonl" | grep -q "Waits on:" && echo yes)"
check "a draft in a do run by hand gets the soft hint" yes "$(text 'gh pr create --draft' "$fx/do.jsonl" | grep -q "only if the ask needs a finished pull request" && echo yes)"
check "the soft hint never says finish it now" "" "$(text 'gh pr create --draft' "$fx/do.jsonl" | grep -o "Finish it now")"
check "a draft with no transcript gets the soft hint" yes "$(text 'gh pr create --draft' | grep -q "Otherwise stop at the draft" && echo yes)"
check "a missing transcript file gets the soft hint" yes "$(text 'gh pr create --draft' "$fx/gone.jsonl" | grep -q "Otherwise stop at the draft" && echo yes)"
check "a Gitea WIP pull request gets the hint" yes "$(text 'tea pr create --title "WIP: summit" </dev/null' | grep -q "make-it-so" && echo yes)"
check "tea pulls create counts as tea pr create" yes "$(text 'tea pulls create --title "WIP: x"' | grep -q "make-it-so" && echo yes)"
check "a ready pull request gets no make-it-so note" "" "$(text 'gh pr create --title T' | grep -o make-it-so)"
check "a Gitea pull request without WIP gets no note" "" "$(run 'tea pr create --title summit')"
check "the draft flag in a word gets no note" "" "$(run 'echo gh pr created --draft')"
check "a push that opens a draft gets the draft steer alone" 1 "$(nudge 'git push -u origin x && gh pr create --draft' | wc -l)"
check "the draft steer exits 0, so Claude Code reads it as a note" 0 "$(run 'gh pr create --draft' >/dev/null; echo $?)"
check "a push still gets the body reminder" yes "$(text 'git push' | grep -q "You pushed" && echo yes)"
exit $fail
