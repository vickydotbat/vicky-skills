#!/usr/bin/env bash
# approved-spec: the examples approved on 2026-11-06 for "step-guard reads
# commands, not text that mentions them" (Q1 to Q4). Each check is named after
# its example. A session that ran do and sentinels but never review makes
# `gh pr ready` refused; text that only names the command must run.
set -u
guard="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/step-guard.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
fail=0
started() { jq -nc --arg s "$1" '{type:"assistant",message:{content:[{type:"tool_use",name:"Skill",input:{skill:$s}}]}}'; }
{ started vicky-skills:do; started vicky-skills:sentinels; } > "$dir/noreview.jsonl"
mkdir "$dir/bin"
printf '#!/bin/sh\necho "Plan check: none found"\n' > "$dir/bin/gh"; chmod +x "$dir/bin/gh"
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
# The guard's exit status for a command in that session.
run() { jq -nc --arg c "$1" --arg t "$dir/noreview.jsonl" '{tool_input:{command:$c},transcript_path:$t}' |
  env PATH="$dir/bin:$PATH" CLAUDE_PLUGIN_OPTION_STEP_GUARD=true "$guard" >/dev/null 2>&1; echo $?; }

# Given a session that ran do but not review, with step-guard on
# When the agent runs a command that only holds the words "gh pr ready" inside a quoted string, such as a comment body
# Then the command runs, with nothing refused
check "Q1 a command that holds the words gh pr ready only inside a quoted string runs" \
  '[ "$(run "gh pr comment 12 --body \"Mark it with gh pr ready when green\"")" = 0 ] && [ "$(run "echo '"'"'run gh pr ready 12 later'"'"'")" = 0 ]'

# Given the same session
# When the agent runs a command whose heredoc body holds the words "gh pr ready"
# Then the command runs, with nothing refused
check "Q2 a command whose heredoc body holds the words gh pr ready runs" \
  '[ "$(run "$(printf "cat <<EOF\nthen gh pr ready 12\nEOF")")" = 0 ]'

# Given the same session
# When the agent runs gh pr ready 12, alone or chained after another command with && or ;
# Then it is refused, naming the missing review
check "Q3 gh pr ready 12, alone or chained, is still refused" \
  '[ "$(run "gh pr ready 12")" = 2 ] && [ "$(run "git status && gh pr ready 12")" = 2 ] && [ "$(run "git status; gh pr ready 12")" = 2 ]'

# Given the same session
# When the agent runs gh pr comment with a quoted body and then, in the same command, gh pr ready 12
# Then it is refused
check "Q4 a quoted body beside the real gh pr ready 12 does not hide it" \
  '[ "$(run "gh pr comment 12 --body \"about gh pr ready\" && gh pr ready 12")" = 2 ]'
exit $fail
