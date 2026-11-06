#!/usr/bin/env bash
# Approved examples for familiar fix 12, ticked 2026-11-06: a hint before a
# pull request body goes up names ship-it and human-voice.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
hint="$root/plugins/vicky-skills/scripts/pr-body-hint.sh"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
run() { jq -nc --arg c "$1" '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:$c}}' | bash "$hint" 2>/dev/null; }

# Given an agent is about to run gh pr create or gh pr edit with a body
# When the command starts
# Then one line of context says to write the body with ship-it and human-voice and pass it with --body-file
for c in 'gh pr create --title T --body "x"' 'gh pr edit 3 --body-file b.md'; do
  out=$(run "$c")
  ctx=$(jq -r '.hookSpecificOutput.additionalContext // empty' <<<"$out" 2>/dev/null)
  check "12 a hint at: $c" '[ "$(wc -l <<<"$ctx")" = 1 ] && grep -q ship-it <<<"$ctx" && grep -q human-voice <<<"$ctx" && grep -q -- --body-file <<<"$ctx"'
done
check "12 no hint on a command that sends no body" '[ -z "$(run "gh pr view 3")" ] && [ -z "$(run "echo gh pr create --body x")" ]'
check "12 the hint is registered before Bash runs" 'jq -e "[.hooks.PreToolUse[] | select(.matcher==\"Bash\") | .hooks[].command | select(test(\"pr-body-hint.sh\"))] | length == 1" "$root/plugins/vicky-skills/hooks/hooks.json" >/dev/null'

# Given the body already has every ship-it section
# When the command runs
# Then pr-guard lets it through as before
check "12 pr-guard still passes a full body" 'bash "$root/tests/pr-guard.test.sh" >/dev/null 2>&1'
exit $fail
