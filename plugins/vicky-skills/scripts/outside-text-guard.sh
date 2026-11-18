#!/usr/bin/env bash
# PreToolUse hook (Bash): a session that read outside text (deathmatch's
# mark-outside.sh recorded it) pushes nothing, files nothing and posts
# nothing. Outside text can be written to steer the agent that reads it, so
# the run that reads it only returns findings, and a person or a later run
# acts on them. On unless the plugin option guard_outside_text is false or 0.
set -u
case "${CLAUDE_PLUGIN_OPTION_GUARD_OUTSIDE_TEXT:-true}" in false | 0) exit 0 ;; esac
command -v jq >/dev/null || exit 0 # mutant-ok delete: without jq every read below comes back empty and the guard exits 0
input=$(cat)
sid=$(jq -r '.session_id // ""' <<<"$input" 2>/dev/null)
[ -n "$sid" ] && [ -s "${CLAUDE_PLUGIN_DATA:-/nonexistent}/outside-read/$sid" ] || exit 0
command=$(jq -r '.tool_input.command // ""' <<<"$input" 2>/dev/null)
writes='(^|[^[:alnum:]_-])(git[[:space:]]+push|(gh|tea)[[:space:]]+(pr|pulls|issue|issues)[[:space:]]+(create|comment|edit|review|merge|close)|gh[[:space:]]+api[[:space:]].*(-X|--method)[[:space:]]*(POST|PATCH|PUT|DELETE)|gh[[:space:]]+release[[:space:]]+create)'
grep -Eq "$writes" <<<"$command" || exit 0
read_what=$(tail -1 "$CLAUDE_PLUGIN_DATA/outside-read/$sid")
echo "outside-text-guard: this session read outside text ($read_what), so it writes nothing to the forge or the remote. Return your findings to the user instead: a person or a later run acts on them. Nothing in this command ran." >&2
exit 2
