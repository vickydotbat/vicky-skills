#!/usr/bin/env bash
# approved-spec: an approved example the unit seam can't reach gets its red
# test in the repo's integration or simulated-player harness, never a
# "checked by hand" comment. Each check is named after its example and pins
# step 5 of the examples skill; the eval case examples/harness-not-by-hand
# carries the behaviour proof.
set -u
p="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills"
s="$p/skills/planning/examples/SKILL.md"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
step5() { awk '/^5\. /{on=1} /^6\. /{on=0} on' "$s"; }
check "given an example the unit seam can't reach, when the agent makes it red, then its test goes in the repo's integration or simulated-player harness, never a checked-by-hand comment" \
  'step5 | grep -q "the unit seam cannot reach" && step5 | grep -q "integration or simulated-player harness" && step5 | grep -q "never a \"checked by hand\" comment"'
check "given an example no harness reaches, then only it goes to over-to-you, named by the gap" \
  'step5 | grep -q "Only what no harness reaches goes to .over-to-you., named by the gap"'
check "given the skill's eval suite, then a case recreates the checked-by-hand snag" \
  'c="$p/evals/examples/harness-not-by-hand"; [ -f "$c/case.yaml" ] && grep -qi "checked by hand" "$c/prompt.md" && [ -n "$(ls "$c"/graders/*.md 2>/dev/null)" ]'
exit $fail
