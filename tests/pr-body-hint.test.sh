#!/usr/bin/env bash
# pr-body-hint: every decision the hook makes.
set -u
hint="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/pr-body-hint.sh"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
run() { jq -nc --arg c "$1" '{tool_input:{command:$c}}' | bash "$hint" 2>/dev/null; }
hinted() { [ "$(run "$1" | jq -r '.hookSpecificOutput.additionalContext' 2>/dev/null)" = "Write this pull request body with the ship-it skill, run human-voice on it, and pass it with --body-file." ]; }
check "create with --body is hinted" 'hinted "gh pr create --draft --body x"'
check "edit with -F is hinted" 'hinted "gh pr edit 4 -F b.md"'
check "create with -b is hinted" 'hinted "gh pr create -b x"'
check "create with --fill is hinted" 'hinted "gh pr create --fill"'
check "a forge command after cd && is hinted" 'hinted "cd repo && gh pr create --body-file b.md"'
check "a forge command after ; is hinted" 'hinted "true; gh pr edit 2 --body x"'
check "create with no body is quiet" '[ -z "$(run "gh pr create --title T")" ]'
check "gh pr view is quiet" '[ -z "$(run "gh pr view 3 --body")" ]'
check "gh pr create inside quotes is quiet" '[ -z "$(run "echo \"gh pr create --body x\"")" ]'
check "gh pr create in a heredoc is quiet" '[ -z "$(run "$(printf "cat <<X\ngh pr create --body x\nX")")" ]'
check "a word ending in gh is quiet" '[ -z "$(run "sigh pr create --body x")" ]'
check "the setting off is quiet" '[ -z "$(jq -nc "{tool_input:{command:\"gh pr create --body x\"}}" | CLAUDE_PLUGIN_OPTION_GUARD_PR=false bash "$hint")" ] && [ -z "$(jq -nc "{tool_input:{command:\"gh pr create --body x\"}}" | CLAUDE_PLUGIN_OPTION_GUARD_PR=0 bash "$hint")" ]'
check "the setting 1 hints" '[ -n "$(jq -nc "{tool_input:{command:\"gh pr create --body x\"}}" | CLAUDE_PLUGIN_OPTION_GUARD_PR=1 bash "$hint")" ]'
check "bad input is quiet and exits 0" 'out=$(echo "not json" | bash "$hint"); [ $? = 0 ] && [ -z "$out" ]'
check "with no jq it exits 0 quietly" 'out=$(echo "{}" | PATH=/nonexistent "$BASH" "$hint" 2>&1); [ -z "$out" ]'
check "a forge command after ; inside quotes is quiet" '[ -z "$(run "echo \";gh pr create --body x\"")" ]'
check "an unclosed quote is read as it stands" 'hinted "gh pr create --body \"x"'
check "a quiet pass exits 0" 'jq -nc "{tool_input:{command:\"gh pr create --title T\"}}" | bash "$hint" >/dev/null 2>&1'
check "the setting off exits 0" 'jq -nc "{tool_input:{command:\"gh pr view\"}}" | CLAUDE_PLUGIN_OPTION_GUARD_PR=false bash "$hint" >/dev/null 2>&1'
check "a masker failure reads the whole command" 'hinted "echo \";gh pr create --body x"'
exit $fail
