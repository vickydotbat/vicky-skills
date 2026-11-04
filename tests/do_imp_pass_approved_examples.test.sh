#!/usr/bin/env bash
# Approved examples for S6: before do builds, its plan check argues against the
# plan. When do starts, step-hint tells the agent what the pass checks and
# how it reports. The agent's own reading of the plan is model behaviour no
# shell test can run: these tests hold the seam the plugin owns.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
hint=$(jq -nc '{tool_input:{skill:"vicky-skills:do"}}' | CLAUDE_PLUGIN_OPTION_STEP_GUARD=true bash "$root/scripts/step-hint.sh" | jq -r '.hookSpecificOutput.additionalContext')

# Given a plan for a build that contradicts a rule you stated in this effort
# When do is about to write its first test or line of code
# Then the agent first names the rule and the clash, and changes the plan or asks you about it
check "E10 do starts with a plan check that names a clash with your rules" 'grep -qF "Before the first test or line of code, run the plan check: argue against the plan" <<<"$hint" \
  && grep -qF "name each rule the user stated in this effort that the plan breaks, and the clash, then change the plan or ask the user" <<<"$hint"'

# Given a plan that rests on the state of a file, setting or branch nobody read this session
# When do is about to build
# Then the agent reads that source and quotes it before building on it
check "E11 the plan check reads and quotes each premise nobody read this session" 'grep -qF "read and quote each file, setting or branch the plan rests on that nobody read this session" <<<"$hint"'

# Given a plan that clashes with no rule and rests only on what was read this session
# When do runs its plan check
# Then no question reaches you, the build goes on, and the report has one line saying the check found nothing
check "E12 a clean pass asks nothing, goes on and reports one line" 'grep -qF "A pass that finds nothing asks nothing and builds on" <<<"$hint" \
  && grep -qF "the pull request body gets one \"Plan check:\" line saying what it found" <<<"$hint"'

exit $fail
