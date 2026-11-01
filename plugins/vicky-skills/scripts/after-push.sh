#!/usr/bin/env bash
# PostToolUse hook: a push can change what the pull request body describes, so
# remind the agent to make the body and its work items true again. A draft
# pull request just opened in a session that started `warp` gets a steer to
# finish it with make-it-so; any other draft gets a hint to finish only when
# the ask needs a finished pull request, since a `do` the user started by hand
# may get more steps from them. Only adds context; it never blocks. Needs jq;
# without it, it stays silent.
set -u
command -v jq >/dev/null || exit 0 # mutant-ok delete: without the tool every later read comes back empty, and the hook exits 0 the same way
input=$(cat)
command="$(jq -r '.tool_input.command // empty' <<<"$input" 2>/dev/null)"
transcript="$(jq -r '.transcript_path // empty' <<<"$input" 2>/dev/null)"
say() { jq -n --arg t "$1" '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $t}}'; }
if [[ "$command" =~ (^|[[:space:];\&|])(gh[[:space:]]+pr[[:space:]]+create[[:space:]].*--draft|tea[[:space:]]+(pr|pulls)[[:space:]]+create[[:space:]].*WIP:) ]]; then
  if [ -n "$transcript" ] && grep -qE 'vicky-skills:warp|"skill": *"warp"' "$transcript" 2>/dev/null; then
    say "You opened a draft pull request in a warp run. Finish it now with the make-it-so skill, through green CI, without asking. Stop only at a gate: a decision of the user's or another person's move. Then write that gate into the pull request as a \`Waits on:\` line."
  else
    say "You opened a draft pull request. Finish it with the make-it-so skill only if the ask needs a finished pull request (\"one PR\", \"ship it\", \"done\"). Otherwise stop at the draft and report it."
  fi
  exit 0
fi
[[ "$command" =~ (^|[[:space:];\&|])git[[:space:]]+push([[:space:]]|$) ]] || exit 0
say "You pushed. Before you report done: reread the open pull request body (gh pr view, or tea pr <n> --comments) against the diff from the base branch, and rewrite any sentence the push made untrue. Then give every work item the branch, commits or body names its verdict: a Closes line, a narrowed body, or the reference removed."
