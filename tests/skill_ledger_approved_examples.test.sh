#!/usr/bin/env bash
# approved-spec: the examples approved on the star "A ledger records each
# skill start". Each check is named after its example.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
hook="$root/plugins/vicky-skills/scripts/skill-ledger.sh"
data=$(mktemp -d); trap 'rm -rf "$data"' EXIT
ledger="$data/skill-ledger.tsv"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
# Runs the hook with the setting at $1 on the event JSON in $2.
run() { CLAUDE_PLUGIN_OPTION_SKILL_LEDGER="$1" CLAUDE_PLUGIN_DATA="$data" bash "$hook" <<<"$2"; }
started='{"hook_event_name": "PreToolUse", "tool_name": "Skill", "tool_input": {"skill": "vicky-skills:warp", "args": "chart B"}}'
typed() { printf '{"hook_event_name": "UserPromptExpansion", "expansion_type": "%s", "command_name": "%s", "command_source": "plugin", "prompt": "/%s"}' "$1" "$2" "$2"; }

out=$(run true "$started"); code=$?
check "the agent starting the warp skill adds one line with the time and \"vicky-skills:warp\"" \
  '[ $code = 0 ] && [ -z "$out" ] && [ "$(wc -l < "$ledger")" = 1 ] && grep -qP "^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ\tvicky-skills:warp$" "$ledger"'

run true "$(typed slash_command vicky-skills:sup)"; run true "$(typed slash_command sup)"
check "typing /vicky-skills:sup adds one line with the time and the skill's name" \
  '[ "$(wc -l < "$ledger")" = 3 ] && tail -2 "$ledger" | cut -f2 | tr "\n" " " | grep -qx "vicky-skills:sup sup "'

run true "$(typed mcp_prompt github:pr-review)"
check "an MCP server's prompt, which is no skill, leaves the ledger as it was" \
  '[ "$(wc -l < "$ledger")" = 3 ]'

rm -f "$ledger"
for setting in false "" 0; do run "$setting" "$started"; done
out=$(env -u CLAUDE_PLUGIN_OPTION_SKILL_LEDGER CLAUDE_PLUGIN_DATA="$data" bash "$hook" <<<"$started")
check "with the setting off, as it is by default, no ledger file exists" \
  '[ ! -e "$ledger" ] && [ -z "$out" ] && grep -A4 "\"skill_ledger\"" "$root/plugins/vicky-skills/.claude-plugin/plugin.json" | grep -q "\"default\": false"'

run true "$started"
check "nothing is sent off the machine, and the ledger sits in the plugin's own data folder" \
  '[ -s "$ledger" ] && ! grep -qE "curl|wget|\bnc\b|https?://" "$hook" && grep -q "CLAUDE_PLUGIN_DATA/skill-ledger.tsv" "$hook"'

bullet=$(grep -F '(`skill_ledger`' "$root/README.md")
check "the README's skill ledger bullet says what one line records, where the file is, and how to delete it" \
  'grep -q "time" <<<"$bullet" && grep -q "skill.s name" <<<"$bullet" && grep -q "skill-ledger.tsv" <<<"$bullet" && grep -qi "delete" <<<"$bullet"'
exit $fail
