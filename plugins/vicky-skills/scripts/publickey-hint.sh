#!/usr/bin/env bash
# PostToolUse hook (Bash; guard_publickey_hint, on by default): when a command's
# output holds "Permission denied (publickey)", adds one line of context before
# the agent tells the user their key is missing. A forge that is failing turns
# away a key it already holds, and an agent once sent the user to re-add a key
# GitHub had on file. The hint names the checks that tell the two apart.
case "${CLAUDE_PLUGIN_OPTION_GUARD_PUBLICKEY_HINT:-true}" in true|1) ;; *) exit 0 ;; esac
command -v jq >/dev/null || exit 0 # mutant-ok delete: without the tool the output reads back empty, and the hook exits 0 the same way
out=$(jq -r '.tool_response | if type == "object" then [.stdout, .stderr, .output] | map(select(. != null)) | join("\n") else tostring end' 2>/dev/null)
grep -qF 'Permission denied (publickey)' <<<"$out" || exit 0
hint='A push or fetch was refused with "Permission denied (publickey)". Before you tell the user their key is missing, prove it: compare `ssh-add -L` and the local ~/.ssh/*.pub with the keys the forge holds (`gh api user/keys` on GitHub), and read the forge'"'"'s status page (https://www.githubstatus.com/api/v2/components.json, "Git Operations", on GitHub). A key the forge already holds, or a degraded status, means the forge is failing: retry with watch.sh and say so. Only a key the forge lacks goes to the user.'
jq -nc --arg h "$hint" '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$h}}'
