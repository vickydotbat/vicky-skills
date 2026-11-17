#!/usr/bin/env bash
# approved-spec: machine-spirit's CI doctrine. Each rule sits in the step
# where the agent makes that decision, and SOURCES.md holds the quote behind
# it. Each check is named after its example and pins the skill text; the eval
# case machine-spirit/biggest-cost-first carries the behaviour proof.
set -u
d="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills"
s="$d/skills/engineering/machine-spirit/SKILL.md"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
step() { awk -v n="$1" '$0 ~ "^"n"\\. "{on=1;print;next} on && /^[0-9]+\. /{on=0} on && /^## /{on=0} on' "$s"; }
check "given a CI change, when the agent picks where it lives, then step 2 names the layer that owns each decision and the change names its layer" \
  'step 2 | grep -q "| Decision | Owner | Wrong-layer tell |" && step 2 | grep -q "Done when each change in the diff names its layer"'
check "given a machine without the workflow-lint hook, when the agent writes a workflow, then step 4 has it run actionlint itself on every workflow file the diff touches" \
  'step 4 | grep -q "Without the workflow-lint hook" && step 4 | grep -q "every workflow file the diff touches"'
check "given slow CI, when the agent budgets it, then it reads the base branch runs as the baseline, fixes the biggest measured cost first, and measures again" \
  'step 6 | grep -q "baseline" && step 6 | grep -q "biggest measured cost first" && step 6 | grep -q "measure again"'
check "given a red run, when the agent fixes it, then it names the cause before any edit, and a retry, raised timeout, sleep, skipped test or continue-on-error never lands as the fix" \
  'step 7 | grep -q "Name the cause before you edit" && step 7 | grep -q "a retry, a raised timeout, a sleep, a skipped or deleted test, \`continue-on-error\`, a loosened assertion or a cache cleared by hand"'
check "given a doctrine rule, then SOURCES.md quotes its primary source with a date or version" \
  'f="$d/skills/engineering/machine-spirit/SOURCES.md"; [ -f "$f" ] && grep -q "Continuous Integration" "$f" && grep -q "2024" "$f" && grep -q "SOURCES.md" "$s"'
check "given the skill's eval suite, then a case recreates the duct-tape snag" \
  'c="$d/evals/machine-spirit/biggest-cost-first"; [ -f "$c/prompt.md" ] && [ -n "$(ls "$c"/graders/*.md 2>/dev/null)" ]'
exit $fail
