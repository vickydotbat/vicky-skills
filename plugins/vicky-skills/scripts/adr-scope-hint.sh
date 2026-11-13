#!/usr/bin/env bash
# PreToolUse hook (Edit, Write, MultiEdit): when the target is a decision
# record (an adr/NNNN-*.md file), adds one line of context with the record
# scope rule, so a record about one feature becomes a code comment instead.
# Never blocks. On unless the plugin option adr_scope_hint is false or 0.
case "${CLAUDE_PLUGIN_OPTION_ADR_SCOPE_HINT:-}" in false | 0) exit 0 ;; esac
command -v jq >/dev/null || exit 0 # mutant-ok delete: without the tool every later read comes back empty, and the hook exits 0 the same way
path=$(jq -r 'select(.tool_name | test("^(Edit|Write|MultiEdit)$")) | .tool_input.file_path // ""' 2>/dev/null)
[[ "$path" =~ (^|/)adr/[0-9]{4}-[^/]*\.md$ ]] || exit 0
jq -n '{hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: "A decision record is macro architecture, never micro: a broad why that many decisions rest on and the code cannot show. When its rule names one class, spell, feat, item, race, window or value, write it as a comment at the code that builds it instead. See the Scope in the decision-record skill FORMAT.md. An accepted record changes only by one appended Status line: write and supersede records with that skill."}}'
