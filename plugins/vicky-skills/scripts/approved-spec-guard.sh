#!/usr/bin/env bash
# Asks the human before an agent edits a file that holds approved examples.
# shortcut: an edit made through Bash (sed, a heredoc) passes, the repo's merge gate (a code-owner rule or CI) catches those.
command -v jq >/dev/null || exit 0
file=$(jq -r '.tool_input.file_path // empty')
# A file named for approved examples, or one holding a marked test, is the contract.
if ! { basename "$file" | grep -qiE 'approved_?examples' || { [ -f "$file" ] && grep -q 'approved-spec' "$file"; }; }; then exit 0; fi
jq -n --arg f "$file" '{hookSpecificOutput: {
  hookEventName: "PreToolUse",
  permissionDecision: "ask",
  permissionDecisionReason: ("\($f) holds approved examples. An approved example changes only when the human approves the new text.")
}}'
