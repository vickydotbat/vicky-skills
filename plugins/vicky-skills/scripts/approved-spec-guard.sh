#!/usr/bin/env bash
# Asks the human before an agent edits a file that holds approved-spec tests.
# shortcut: an edit made through Bash (sed, a heredoc) passes, the repo's CI check is the gate for that.
command -v jq >/dev/null || exit 0
file=$(jq -r '.tool_input.file_path // empty')
[ -f "$file" ] && grep -q 'approved-spec' "$file" || exit 0
jq -n --arg f "$file" '{hookSpecificOutput: {
  hookEventName: "PreToolUse",
  permissionDecision: "ask",
  permissionDecisionReason: ("\($f) holds approved-spec tests. An approved example changes only when the human approves the new text.")
}}'
