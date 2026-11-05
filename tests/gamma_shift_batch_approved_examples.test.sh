#!/usr/bin/env bash
# approved-spec: the gamma-shift batch examples, approved 2026-11-02 on the
# ticket "Gamma shift: one PR per run, one builder per batch". The skill text
# is what the agent runs, so each check reads the step that sets the behaviour.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills"
skill="$root/skills/engineering/gamma-shift/SKILL.md"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
. "$(dirname "$0")/lib/skill-step.sh"; step() { skill_step "$skill" "$1"; }

# Given 3 cleared tickets wait
# When the session starts
# Then one background builder runs, not 3
check "one builder for a batch" 'step 4 | grep -q "one background subagent for the whole batch" && ! step 4 | grep -q "For each, dispatch one background subagent"'

# Given 5 cleared tickets of different sizes wait
# When the session starts
# Then the batch takes the 3 smallest, in order from smallest
check "a batch holds at most three, smallest first" 'step 4 | grep -q "at most three cleared tickets, smallest first"'

# Given 5 cleared tickets wait and the first batch has finished
# When the session goes on
# Then no second batch starts by itself
check "one batch per session" 'step 4 | grep -q "One batch per session" && step 4 | grep -q "the user types \"gamma shift\""'

# Given 12 cleared tickets wait and the batch took 3
# When the session starts
# Then she sees one line, "9 more waiting, say gamma shift for them"
check "the rest is one line" 'grep -q "<n> more waiting, say gamma shift for them" "$skill" && grep -q "only when more than three cleared" "$skill"'
exit $fail
