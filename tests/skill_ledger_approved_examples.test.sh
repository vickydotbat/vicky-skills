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

# Network tools on PATH are shims that leave a mark when anything runs them.
shims="$data/../shims-$$"; mkdir -p "$shims"; trap 'rm -rf "$data" "$shims"' EXIT
for tool in curl wget nc ssh; do printf '#!/bin/sh\ntouch "%s/called"\n' "$shims" > "$shims/$tool"; chmod +x "$shims/$tool"; done
PATH="$shims:$PATH" run true "$started"
check "nothing is sent off the machine, and the ledger sits in the plugin's own data folder" \
  '[ -s "$ledger" ] && [ ! -e "$shims/called" ] && [ "$(ls -A "$data")" = skill-ledger.tsv ]'

# Tested unasked: the guards the mutation pass showed no test reached.
out=$(env -u CLAUDE_PLUGIN_DATA CLAUDE_PLUGIN_OPTION_SKILL_LEDGER=true bash "$hook" <<<"$started"); code=$?
check "with the setting on and no plugin data folder, it exits 0 and prints nothing" '[ $code = 0 ] && [ -z "$out" ]'
rm -f "$ledger"; run true "$(typed slash_command /sup)"
check "a typed name with a leading slash is recorded without it" '[ "$(cut -f2 "$ledger")" = sup ]'
fresh="$data/new/folder"; CLAUDE_PLUGIN_OPTION_SKILL_LEDGER=true CLAUDE_PLUGIN_DATA="$fresh" bash "$hook" <<<"$started"
check "a data folder that does not exist yet is made, and the line lands in it" '[ -s "$fresh/skill-ledger.tsv" ]'
touch "$data/afile"; CLAUDE_PLUGIN_OPTION_SKILL_LEDGER=true CLAUDE_PLUGIN_DATA="$data/afile/sub" bash "$hook" <<<"$started"; code=$?
check "a data folder that cannot be made leaves the skill unblocked: exit 0" '[ $code = 0 ]'
mkdir -p "$data/blocked/skill-ledger.tsv"; err=$(CLAUDE_PLUGIN_OPTION_SKILL_LEDGER=true CLAUDE_PLUGIN_DATA="$data/blocked" bash "$hook" <<<"$started" 2>&1 >/dev/null); code=$?
check "a ledger it cannot write leaves the skill unblocked: exit 0, and nothing on stderr" '[ $code = 0 ] && [ -z "$err" ]'
exit $fail
