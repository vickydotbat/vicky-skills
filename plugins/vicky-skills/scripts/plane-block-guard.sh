#!/usr/bin/env bash
# PreToolUse hook (Bash): refuses `plane block <item> <blocker>` unless the
# command ends with a "# hard: <reason>" comment. Plane's API can add a
# blocked-by relation but never remove one, so a link written while scope
# still moves stays until a person deletes it in the web interface. Matches
# `plane` on the PATH and a repo's `bin/plane`. Off unless the plugin option
# guard_plane_block is true.
case "${CLAUDE_PLUGIN_OPTION_GUARD_PLANE_BLOCK:-}" in true|1) ;; *) exit 0 ;; esac
command -v jq >/dev/null || exit 0 # mutant-ok delete: without the tool every later read comes back empty, and the hook exits 0 the same way
command=$(jq -r '.tool_input.command // empty')
[[ $command =~ (^|[[:space:]\;\&\|\(])(\./)?(bin/)?plane[[:space:]]+block[[:space:]]+([^[:space:]\;\&\|]+)[[:space:]]+([^[:space:]\;\&\|#]+) ]] || exit 0
item=${BASH_REMATCH[4]} blocker=${BASH_REMATCH[5]}
grep -Eq '#[[:space:]]*hard:[[:space:]]*[^[:space:]]' <<<"$command" && exit 0
echo "plane-block-guard: a blocked-by link is one only a person can remove, in Plane's web interface." >&2
echo "Write \"Waits on: $blocker (<why>)\" in $item's body instead. Block only when $item calls code or needs an answer $blocker produces, and say so: end the command with \"# hard: <what of $blocker's work it needs>\"." >&2
exit 2
