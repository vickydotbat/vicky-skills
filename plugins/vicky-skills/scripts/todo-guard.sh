#!/usr/bin/env bash
# PreToolUse hook (Edit, Write, Bash; guard_todo_next, on by default): .todo
# changes go through standing-orders' todo.sh only. An edit or write to a .todo
# file, or a shell command that writes one (a redirect, sed -i, tee, rm, mv)
# without todo.sh, is refused with a steer to todo.sh. A read passes.
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
jq -n '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:"todo-guard: refused, .todo changes go through standing-orders/scripts/todo.sh under the plugin root: todo.sh add <line> or todo.sh done <text>, which keeps each line to its form. Nothing in this command ran: run todo.sh, then the rest of the command on its own."}}'
