#!/usr/bin/env bash
# PostToolUse hook (Bash; guard_rebase_monks_hint, on by default): when a
# git rebase stops on a conflict and the session has not started
# history-monks, adds one line of context. A conflict settled by hand drops
# what the landed change was for; history-monks reads the landed commits and
# keeps their form. An agent once settled such a conflict by hand, and two
# reviewers had to catch it.
case "${CLAUDE_PLUGIN_OPTION_GUARD_REBASE_MONKS_HINT:-true}" in false|0) exit 0 ;; esac
payload=$(cat)
cmd=$(jq -r '.tool_input.command // ""' <<<"$payload" 2>/dev/null)
grep -qE '(^|[;&|[:space:]])git([[:space:]]+-[^[:space:]]+([[:space:]]+[^-[:space:]][^[:space:]]*)?)*[[:space:]]+rebase([[:space:]]|$)' <<<"$cmd" || exit 0
jq -r '[.tool_response | .. | strings] | join("\n")' <<<"$payload" 2>/dev/null | grep -qE '^CONFLICT|could not apply' || exit 0
transcript=$(jq -r '.transcript_path // empty' <<<"$payload" 2>/dev/null)
jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="tool_use" and .name=="Skill") | .input.skill // ""' "$transcript" 2>/dev/null | grep -qE '(^|:)history-monks$' && exit 0
jq -n '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:"The rebase stopped on a conflict, and this session has not started history-monks. Run git rebase --abort, start the history-monks skill, and rebase again under it: it reads what each landed commit was for and settles the conflict in that form, where a hand fix keeps only the branch side."}}'
