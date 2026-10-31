#!/usr/bin/env bash
# approved-spec: the examples approved on the ticket "Rebuild do and examples so
# the examples are the seams" and the three the spec review found missing. These are agent behaviours, so each check reads
# the skill text that makes the agent do it.
set -u
s="$(dirname "$0")/../plugins/vicky-skills/skills/engineering"
do="$s/do/SKILL.md"; ex="$s/examples/SKILL.md"; mu="$s/sentinels/SKILL.md"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
step() { awk -v n="$2" '$0 ~ "^"n"\\. " {p=1; print; next} p && /^[0-9]+\. |^## / {exit} p' "$1"; }

check "given a change asked in chat, examples open in the editor before any test or code is written" \
  'step "$do" 1 | grep -q "examples" && step "$do" 1 | grep -q "red-pen" && step "$do" 1 | grep -q "before any test or code"'
check "given approved examples on the ticket, no editor opens and the build goes straight to red tests" \
  'step "$do" 1 | grep -q "already holds approved examples" && step "$do" 1 | grep -q "no editor"'
check "edge cases are drafted up front as examples of their own" \
  'step "$ex" 2 | grep -q "limit, error path and odd input"'
check "the agent never asks where its tests go" \
  '! grep -qi "agree the seams\|agreed seam" "$do" && grep -q "Never ask the user where a test goes" "$do"'
check "each approved example has a test named after it, and the report shows them passing" \
  'grep -q "Name the test after the example" "$ex" && grep -q "The approved tests are the goal" "$do" && step "$do" 3 | grep -q "Done when every approved test passes"'
check "a planted bug no approved test catches shows in the mutation report killed by a test, or marked equivalent with a reason" \
  'grep -q "Answer every survivor\*\*: a test that kills it" "$mu" && step "$do" 4 | grep -q "Kill each survivor with a test, or mark it equivalent with its reason, and put the counts in the report"'
check "a test that only fails on a refactor, a content edit or a library upgrade is not in the pull request" \
  'grep -q "A test that can only go red on a refactor, a content edit or a library upgrade proves nothing" "$do"'
check "a behaviour no approved example names, met mid-build, waits as a draft and the rest still lands" \
  'step "$do" 3 | grep -q "park that slice, and build the rest"'
check "a refactor with no approved examples gets guard tests that pass on main first, listed in the pull request" \
  'step "$s/spark-joy/SKILL.md" 3 | grep -q "pass on .main. before you change anything" && grep -q "guard tests" "$s/spark-joy/SKILL.md"'
exit $fail
