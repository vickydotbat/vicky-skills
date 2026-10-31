#!/usr/bin/env bash
# PreToolUse (Skill) and UserPromptExpansion hook: with the plugin option
# skill_ledger on, adds one line per skill start to skill-ledger.tsv in the
# plugin's data folder: the UTC time, a tab, and the skill's name. The agent
# starting a skill reaches PreToolUse, and a typed /skill reaches
# UserPromptExpansion only. Off by default. It prints nothing and exits 0, so
# it never blocks the skill it records.
set -u
case "${CLAUDE_PLUGIN_OPTION_SKILL_LEDGER:-}" in true|1) ;; *) exit 0 ;; esac
[ -n "${CLAUDE_PLUGIN_DATA:-}" ] || exit 0
command -v jq >/dev/null || exit 0
name=$(jq -r '
  if .hook_event_name == "UserPromptExpansion" then
    (if .expansion_type == "slash_command" then .command_name // "" else "" end)
  else .tool_input.skill // "" end' 2>/dev/null) || exit 0
name=${name#/}
# A name is one word; anything else would break the ledger's columns.
case "$name" in ''|*[!A-Za-z0-9:_.-]*) exit 0 ;; esac
mkdir -p "$CLAUDE_PLUGIN_DATA" 2>/dev/null || exit 0
printf '%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$name" >> "$CLAUDE_PLUGIN_DATA/skill-ledger.tsv" 2>/dev/null
exit 0
