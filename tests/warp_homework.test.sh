#!/usr/bin/env bash
# Warp asks its questions in pre-flight and ships the whole course in one pull request.
set -u
root="$(dirname "$0")/../plugins/vicky-skills"
warp="$root/skills/engineering/warp/SKILL.md"
chart="$root/skills/engineering/lay-course/STAR-CHART.md"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
. "$(dirname "$0")/lib/skill-step.sh"; step() { skill_step "$warp" "$1"; }
section() { awk -v h="$1" '$0 == "## "h {on=1; next} /^## /{on=0} on' "$warp"; }
check "plotting the course sweeps each target's fallout, and the course comment lists it with what settles each item" \
  'step 2 | grep -q "sweep its \*\*fallout\*\*" && step 3 | grep -q "list each target.s fallout from step 2"'
check "pre-flight runs spec-reviewer on each star with no diff yet, and its drafts join the same approval page" \
  'step 4 | grep -q "start one \`spec-reviewer\` per star" && step 4 | grep -q "on the same approval page" && grep -q "no diff yet (a \`warp\`.s pre-flight), run steps 1, 2 and 4 only" "$root/agents/spec-reviewer.md"'
check "pre-flight runs standards-reviewer on the red tests before committing them, and an example whose test can't fail goes back to the user in the same round" \
  'step 4 | grep -q "start \`standards-reviewer\` on the test files" && step 4 | grep -q "still passes with its behaviour deleted.*goes back to the user in this same round"'
check "a warp files no follow-up ticket: no seam, and the asteroid belt's answers are built in the same pull request before the final review" \
  '! grep -q "Carve a seam" "$warp" && grep -q "files no follow-up ticket" "$warp" && section "Mid-flight questions" | grep -q "build each one on the same branch and pull request, with its approved tests red first, then go on to step 6"'
check "inside a warp, do builds a slice parked on the user's decision in the pull request instead of filing a ticket" \
  'grep -q "\*\*Inside a \`warp\`\*\*, a slice parked on the user.s decision" "$root/skills/engineering/do/SKILL.md"'
check "settling a warp's effort leaves no ticket waiting on the user's decision" \
  'grep -q "A \`warp\`.s effort has no Waits on the user.s decision" "$root/skills/engineering/make-it-so/SETTLE.md"'
check "an asteroid belt's answers are built in the same pull request" \
  'grep -E "^\| \*\*asteroid belt\*\* \|" "$chart" | grep -q "builds the answers in the same pull request"'
check "every chart's Unknown unknowns box names fallout and examples that can't fail, in the rule and the template" \
  'grep -q "Every chart names two on its own" "$chart" && grep -q "^- Seen before: fallout on content no star names" "$chart" && grep -q "^- Seen before: an approved example whose test can.t fail" "$chart"'
exit $fail
