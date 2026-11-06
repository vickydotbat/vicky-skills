#!/usr/bin/env bash
# PreToolUse hook (Bash): before a gh pr create or gh pr edit that sends a
# body, adds one line of context naming ship-it and human-voice, so the body
# is right before pr-guard has to refuse it. Off when guard_pr is false or 0.
set -u
case "${CLAUDE_PLUGIN_OPTION_GUARD_PR:-true}" in true | 1) ;; *) exit 0 ;; esac
command -v jq >/dev/null || exit 0
command=$(jq -r '.tool_input.command // ""' 2>/dev/null)
here=$(dirname "$0")
# Heredoc bodies and quoted text are no command, as pr-guard reads them.
code=$(awk -f "$here/heredoc-strip.awk" <<<"$command")
masked=$(awk -f "$here/quote-mask.awk" <<<"$code") && [ -n "$masked" ] || masked=$code
grep -Eq '(^|[;&|(])[[:space:]]*gh[[:space:]]+pr[[:space:]]+(create|edit)([[:space:]]|$)' <<<"$masked" || exit 0
grep -Eq -- '(^|[[:space:]])(--(body|fill)|-[bF]([[:space:]]|$))' <<<"$masked" || exit 0
jq -nc '{hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:"Write this pull request body with the ship-it skill, run human-voice on it, and pass it with --body-file."}}'
