#!/usr/bin/env bash
# approved-spec: the examples approved on the ticket "Rebuild do and examples so
# the examples are the seams". These are agent behaviours, so each check reads
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
check "every test is named after an approved example, and no other test exists" \
  'grep -q "Write no test that no approved example names" "$do" && ! grep -q "tests at its seams" "$ex"'
check "a planted bug no approved test catches comes back as a new example" \
  'grep -q "Answer every survivor\*\*: a missing example" "$mu" && grep -q "survivor.*missing example" "$do"'
exit $fail
