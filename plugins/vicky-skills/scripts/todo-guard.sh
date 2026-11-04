#!/usr/bin/env bash
# PreToolUse hook (Edit, Write, Bash; guard_todo_next, on by default): .todo
# work goes through standing-orders only. An edit or write to a .todo file,
# or a shell command that writes one (a redirect, sed -i, tee, rm, mv), is
# refused until standing-orders has started since the user's last message, which keeps each
# line to its form and length. A read passes.
set -u
case "${CLAUDE_PLUGIN_OPTION_GUARD_TODO_NEXT:-true}" in true|1) ;; *) exit 0 ;; esac
command -v jq >/dev/null || exit 0 # mutant-ok delete: without the tool every later read comes back empty, and the hook exits 0 the same way
payload=$(cat)
tool=$(jq -r '.tool_name // empty' <<<"$payload" 2>/dev/null)
case $tool in
  Edit|Write|MultiEdit) jq -r '.tool_input.file_path // ""' <<<"$payload" | grep -qE '(^|/)\.todo$' || exit 0 ;;
  Bash)
    c=$(jq -r '.tool_input.command // ""' <<<"$payload")
    grep -qE '(>>?|tee([[:space:]]+-a)?)[[:space:]]*([^[:space:];&|]*/)?\.todo([[:space:];&|)]|$)' <<<"$c" ||
      { grep -qE '(^|[[:space:];&|(])(sed[[:space:]]+-i|rm|mv|cp|truncate)[[:space:]]' <<<"$c" && grep -qE '(^|[[:space:]/])\.todo([[:space:];&|)]|$)' <<<"$c"; } || exit 0 ;;
  *) exit 0 ;;
esac
transcript=$(jq -r '.transcript_path // empty' <<<"$payload")
# shellcheck source=since-user.sh
. "$(dirname "$0")/since-user.sh"
[ -f "$transcript" ] && skill_since_user "$transcript" standing-orders && exit 0
jq -n '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:"todo-guard: refused, .todo work goes through the standing-orders skill only, which keeps each line to its form. Nothing ran: start standing-orders, then make the change it describes."}}'
