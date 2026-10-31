#!/usr/bin/env bash
# UserPromptSubmit hook: when the user's message teaches a lesson ("codify",
# "lesson", "for the future", "from now on"), adds one line of context sending
# the agent through engrave before it replies. Off unless the plugin option
# lesson_hint is true.
case "${CLAUDE_PLUGIN_OPTION_LESSON_HINT:-}" in true|1) ;; *) exit 0 ;; esac
command -v jq >/dev/null || exit 0 # mutant-ok delete: without the tool every later read comes back empty, and the hook exits 0 the same way
prompt=$(jq -r '.prompt // ""')
# A report from another agent arrives as a prompt too, and quotes the user's
# lessons back. Only the user teaches one.
grep -Eq '^[[:space:]]*(Another Claude session sent a message|<agent-message)' <<<"$prompt" && exit 0
grep -Eqi 'codif(y|ie)|lesson|for the future|from now on|make sure we know|prevent (this|that|it)' <<<"$prompt" || exit 0
hint='The user is teaching a lesson. Run the engrave skill on it before your reply, and end the reply with its "📓 Engraved:" line.'
jq -nc --arg h "$hint" '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:$h}}'
