#!/usr/bin/env bash
# PostToolUse hook: a push can change what the pull request body describes, so
# remind the agent to make the body and its work items true again. Only adds
# context; it never blocks. Needs jq; without it, it stays silent.
set -u
command -v jq >/dev/null || exit 0
command="$(jq -r '.tool_input.command // empty' 2>/dev/null)"
[[ "$command" =~ (^|[[:space:];\&|])git[[:space:]]+push([[:space:]]|$) ]] || exit 0
jq -n '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext:
  "You pushed. Before you report done: reread the open pull request body (gh pr view, or tea pr <n> --comments) against the diff from the base branch, and rewrite any sentence the push made untrue. Then give every work item the branch, commits or body names its verdict: a Closes line, a narrowed body, or the reference removed."}}'
