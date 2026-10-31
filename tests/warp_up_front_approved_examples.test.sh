#!/usr/bin/env bash
# approved-spec: the example approved for warp during the Todo list warp:
# every approval is taken up front. Reads the instruction that drives the agent.
set -u
warp="$(dirname "$0")/../plugins/vicky-skills/skills/engineering/warp/SKILL.md"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
step() { awk -v n="$1" '$0 ~ "^"n"\\. "{on=1; print; next} /^[0-9]+\. /{on=0} /^## /{on=0} on' "$warp"; }
check "once a warp's examples are approved in pre-flight, every approved test on the course is written and committed in one step before the warp engages, so no guard asks again unless an approved test must change" \
  'step 4 | grep -q "write every approved test on the course in one step" && step 4 | grep -q "before engaging" && step 4 | grep -q "the only guard prompt of the warp"'
exit $fail
