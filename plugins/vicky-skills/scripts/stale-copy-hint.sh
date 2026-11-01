#!/usr/bin/env bash
# UserPromptSubmit hook: a session keeps the plugin copy it started with, so
# after the plugin updates it goes on running the old skills and scripts. When
# the session's copy is not the one installed, tells the agent once a session,
# with both commits, that a restart picks up the new one.
command -v jq >/dev/null || exit 0 # mutant-ok delete: without the tool every later read comes back empty, and the hook exits 0 the same way
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -n "${CLAUDE_PLUGIN_DATA:-}" ] || exit 0
installed="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins/installed_plugins.json"
[ -f "$installed" ] || exit 0
session=$(jq -r '.session_id // empty' | tr -cd 'A-Za-z0-9_-')
[ -n "$session" ] || exit 0 # mutant-ok delete: an empty id names the told folder itself, which exists, so the hook exits 0 the same way
mine=$(basename -- "$CLAUDE_PLUGIN_ROOT")
# The newest install of this plugin, and whether any install is the session's own copy.
newest=$(jq -r --arg p "$(dirname -- "$CLAUDE_PLUGIN_ROOT")" '[.plugins[]?[] | select(.installPath | startswith($p + "/"))]
  | if any(.installPath | endswith("/'"$mine"'")) then empty else (sort_by(.lastUpdated) | last | .installPath // empty) end' "$installed")
[ -n "$newest" ] || exit 0
told="$CLAUDE_PLUGIN_DATA/stale-copy-told"
mkdir -p "$told" && [ ! -e "$told/$session" ] || exit 0
touch "$told/$session"
hint="This session runs an older vicky-skills copy (${mine:0:7}) than the one installed ($(basename -- "$newest" | cut -c1-7)), so its skills and scripts are out of date. Tell the user in one line that a restart picks up the new one."
jq -nc --arg h "$hint" '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:$h}}'
