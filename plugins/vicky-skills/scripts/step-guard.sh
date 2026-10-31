#!/usr/bin/env bash
# PreToolUse hook (Bash): refuses `gh pr ready` in a session that started `do`
# but never started `review`, unless the pull request body says
# "Skipped: review, because <reason>". Reads the session transcript for Skill
# calls. A failed body lookup lets the command through. Off unless the plugin
# option step_guard is true.
# shortcut: GitHub only; Gitea marks ready by editing the title, add it when a
# Gitea repo uses the guard.
case "${CLAUDE_PLUGIN_OPTION_STEP_GUARD:-}" in true|1) ;; *) exit 0 ;; esac
command -v jq >/dev/null || exit 0
payload=$(cat)
cmd=$(jq -r '.tool_input.command // ""' <<<"$payload")
[[ $cmd =~ gh[[:space:]]+pr[[:space:]]+ready([[:space:]]+([0-9]+))? ]] || exit 0
pr=${BASH_REMATCH[2]}
transcript=$(jq -r '.transcript_path // ""' <<<"$payload")
[ -f "$transcript" ] || exit 0
skills=$(jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="tool_use" and .name=="Skill") | .input.skill' "$transcript" 2>/dev/null | sed 's/.*://')
grep -qx do <<<"$skills" || exit 0
grep -qx review <<<"$skills" && exit 0
body=$(timeout 10 gh pr view ${pr:+"$pr"} --json body -q .body 2>/dev/null) || exit 0
grep -q 'Skipped: review, because ' <<<"$body" && exit 0
echo "step-guard: this do build never ran its review step. Run the review skill, or add 'Skipped: review, because <reason>' with its proof to the pull request body." >&2
exit 2
