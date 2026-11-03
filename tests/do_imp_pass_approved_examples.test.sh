#!/usr/bin/env bash
# Approved examples for S6: before do builds, its imp pass argues against the
# plan. When do starts, step-hint tells the agent what the pass checks, and
# step-guard holds the pull request at ready until its body reports the pass.
# The agent's own reading of the plan is model behaviour no shell test can
# run: these tests hold the two seams the plugin owns.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
hint=$(jq -nc '{tool_input:{skill:"vicky-skills:do"}}' | CLAUDE_PLUGIN_OPTION_STEP_GUARD=true bash "$root/scripts/step-hint.sh" | jq -r '.hookSpecificOutput.additionalContext')
started() { jq -nc --arg s "$1" '{type:"assistant",message:{content:[{type:"tool_use",name:"Skill",input:{skill:$s}}]}}'; }
{ started vicky-skills:do; started vicky-skills:sentinels; started vicky-skills:review; } > "$dir/built.jsonl"
mkdir "$dir/bin"; printf '#!/bin/sh\ncat "%s/body"\n' "$dir" > "$dir/bin/gh"; chmod +x "$dir/bin/gh"
ready() { jq -nc --arg t "$dir/built.jsonl" '{tool_input:{command:"gh pr ready 37"},transcript_path:$t}' |
  PATH="$dir/bin:$PATH" CLAUDE_PLUGIN_OPTION_STEP_GUARD=true bash "$root/scripts/step-guard.sh" 2>&1; echo "exit=$?"; }

# Given a plan for a build that contradicts a rule you stated in this effort
# When do is about to write its first test or line of code
# Then the agent first names the rule and the clash, and changes the plan or asks you about it
check "E10 do starts with an imp pass that names a clash with your rules" 'grep -qF "Before the first test or line of code, run the imp pass: argue against the plan" <<<"$hint" \
  && grep -qF "name each rule the user stated in this effort that the plan breaks, and the clash, then change the plan or ask the user" <<<"$hint"'

# Given a plan that rests on the state of a file, setting or branch nobody read this session
# When do is about to build
# Then the agent reads that source and quotes it before building on it
check "E11 the imp pass reads and quotes each premise nobody read this session" 'grep -qF "read and quote each file, setting or branch the plan rests on that nobody read this session" <<<"$hint"'

# Given a plan that clashes with no rule and rests only on what was read this session
# When do runs its imp pass
# Then no question reaches you, the build goes on, and the report has one line saying the pass found nothing
check "E12 a clean pass asks nothing and goes on" 'grep -qF "A pass that finds nothing asks nothing and builds on" <<<"$hint"'
printf 'Summary\n' > "$dir/body"
check "E12 a pull request with no imp pass line is held at ready" 'ready | grep -q "exit=2"'
printf 'Summary\n\nImp pass: nothing found.\n' > "$dir/body"
check "E12 one line saying the pass found nothing lets it go ready" 'ready | grep -q "exit=0"'

exit $fail
