#!/usr/bin/env bash
# PostToolUse hook (Skill): when `do` starts, adds one line of context saying
# each step needs its proof. Off unless the plugin option step_guard is true.
case "${CLAUDE_PLUGIN_OPTION_STEP_GUARD:-}" in true|1) ;; *) exit 0 ;; esac
command -v jq >/dev/null || exit 0 # mutant-ok delete: without the tool every later read comes back empty, and the hook exits 0 the same way
skill=$(jq -r '.tool_input.skill // ""' | sed 's/.*://')
[ "$skill" = do ] || exit 0
jq -nc '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:"Every do step ends with its proof. To skip one, write \"Skipped: <step>, because <reason>\" with the proof in the pull request body."}}'
