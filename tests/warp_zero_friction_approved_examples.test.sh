#!/usr/bin/env bash
# approved-spec: the examples the user set for warp during the Todo list warp:
# zero friction after a minimal pre-flight. Reads the instruction that drives
# the agent.
set -u
warp="$(dirname "$0")/../plugins/vicky-skills/skills/engineering/warp/SKILL.md"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
step() { awk -v n="$1" '$0 ~ "^"n"\\. "{on=1; print; next} /^[0-9]+\. /{on=0} /^## /{on=0} on' "$warp"; }
section() { awk -v h="$1" '$0 == "## "h {on=1; next} /^## /{on=0} on' "$warp"; }
check "a question or gate past pre-flight that the user leaves unanswered gets the agent's own pick, recorded, and the warp flies on" \
  'grep -q "\*\*Zero friction\.\*\*" "$warp" && section "Mid-flight questions" | grep -q "take your pick, record it" && section "Punch through" | grep -q "take your pick, record it"'
check "pre-flight asks only what the course can't fly without, in one round" \
  'step 4 | grep -q "only what the course can'"'"'t fly without" && step 4 | grep -q "in one round"'
exit $fail
