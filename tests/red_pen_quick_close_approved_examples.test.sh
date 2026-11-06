#!/usr/bin/env bash
# approved-spec: the examples approved for "red-pen counts a quick close".
# Each check is named after its example. The behaviour is the agent's, so each
# check reads the instruction that drives it.
set -u
skill="$(dirname "$0")/../plugins/vicky-skills/skills/productivity/red-pen/SKILL.md"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
. "$(dirname "$0")/lib/skill-step.sh"; step() { skill_step "$1" "$2"; }
open=$(step "$skill" 2)

check "a fast unchanged close is approval as written, whatever the background-task notice says" \
  'grep -q "however soon it comes, means the user takes every draft \*\*as is\*\*: go on to step 3 without asking" <<<"$open" && grep -q "The editor exit is the user'"'"'s close even when it arrives as a background-task notice saying no human input arrived" <<<"$open"'
check "an edited close still writes back the user's changed text, word for word" \
  'step "$skill" 3 | grep -q "Put each block'"'"'s text at its destination word for word"'
exit $fail
