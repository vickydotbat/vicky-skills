#!/usr/bin/env bash
# PostToolUse hook (Bash; guard_publickey_hint, on by default): when a command's
# output holds "Permission denied (publickey)", adds one line of context before
# the agent tells the user their key is missing. A forge that is failing turns
# away a key it already holds, and an agent once sent the user to re-add a key
# GitHub had on file. The hint names the checks that tell the two apart.
# It fires only on a command that runs git, ssh, scp, sftp, rsync or jj, and on
# a line the ssh client writes ("<host>: Permission denied (publickey)"), so
# reading a file that quotes the phrase stays quiet. The ssh client starts that
# line with the host, so a line with anything before the host is ignored.
case "${CLAUDE_PLUGIN_OPTION_GUARD_PUBLICKEY_HINT:-true}" in true|1) ;; *) exit 0 ;; esac
payload=$(cat)
cmd=$(jq -r '.tool_input.command // ""' <<<"$payload" 2>/dev/null)
grep -qE '(^|[;&|(`[:space:]])(git|ssh|scp|sftp|rsync|jj)([[:space:]]|$)' <<<"$cmd" || exit 0
out=$(jq -r '[.tool_response | .. | strings] | join("\n")' <<<"$payload" 2>/dev/null)
grep -qE '^[^[:space:]]+: Permission denied \(publickey' <<<"$out" || exit 0
hint='A push or fetch was refused with "Permission denied (publickey)". Before you tell the user their key is missing, prove it: compare `ssh-add -L` and the local ~/.ssh/*.pub with the keys the forge holds (on GitHub `gh api user/keys`; on Gitea `tea api user/keys </dev/null`; on GitLab `glab api user/keys`), and read the forge'"'"'s status page (on GitHub https://www.githubstatus.com/api/v2/components.json, "Git Operations"). A key the forge already holds, or a degraded status, means the forge is failing: retry with watch.sh and say so. Only a key the forge lacks goes to the user.'
jq -nc --arg h "$hint" '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$h}}'
