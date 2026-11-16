#!/usr/bin/env bash
# approved-spec: the example approved for warp during the Todo list warp:
# every approval is taken up front. Reads the instruction that drives the agent.
set -u
warp="$(dirname "$0")/../plugins/vicky-skills/skills/engineering/warp/SKILL.md"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
. "$(dirname "$0")/lib/skill-step.sh"; step() { skill_step "$warp" "$1"; }
check "once a warp's examples are approved in pre-flight, every approved test on the course is written and committed in one step before the warp engages, so no guard asks again unless an approved test must change" \
  'step 4 | grep -q "write every approved test on the course in one step" && step 4 | grep -q "before engaging" && step 4 | grep -q "the only guard prompt of the warp"'
check "plotting the course sweeps each target's fallout, and every fallout item no example or decision settles becomes a ticket before engaging" \
  'step 2 | grep -q "sweep its \*\*fallout\*\*" && step 2 | grep -q "every unsettled fallout item each target has is a ticket"'
check "pre-flight runs spec-reviewer on each star with no diff yet, and its drafted missing examples join the same approval page" \
  'step 4 | grep -q "start one \`spec-reviewer\` per star" && step 4 | grep -q "on the same approval page"'
check "pre-flight runs standards-reviewer on the red tests before committing them, and an example whose test can't fail goes back to the user in the same round" \
  'step 4 | grep -q "start \`standards-reviewer\` on the test files" && step 4 | grep -q "test can.t fail, or that tests a path nothing calls, goes back to the user in this same round"'
check "a warp files no follow-up ticket: a mid-flight question carves no seam, and the asteroid belt's answers are built in the same pull request before the final review" \
  '! grep -q "Carve a seam" "$warp" && grep -q "files no follow-up ticket" "$warp" && grep -q "build each one on the same branch and pull request, with its approved tests red first, then go on to step 6" "$warp"'
exit $fail
