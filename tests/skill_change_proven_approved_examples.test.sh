#!/usr/bin/env bash
# approved-spec: a skill change is proven by an eval case, never by a test
# that reads the skill's text. Drives the check with a branch's changed paths.
set -u
cd "$(dirname "$0")/.."
check=plugins/vicky-skills/scripts/skill-change-proven.sh
fail=0
run() { printf '%b' "$1" | bash "$check" 2>&1; }

# Given a branch that changes a skill's text and adds an eval case for it
# When the skill-change check runs
# Then it passes
out=$(run 'plugins/vicky-skills/skills/building/do/SKILL.md\nplugins/vicky-skills/evals/do/new-case/prompt.md\n'); rc=$?
if [ "$rc" = 0 ]; then echo "ok   a skill change with an eval case passes"; else echo "FAIL a skill change with an eval case passes: exit $rc: $out"; fail=1; fi

# Given a branch that changes a skill's text and changes only files under tests/
# When the skill-change check runs
# Then it fails, and says a skill change is proven by an eval case
out=$(run 'plugins/vicky-skills/skills/building/do/SKILL.md\ntests/do.test.sh\n'); rc=$?
if [ "$rc" = 1 ] && grep -qi 'eval case' <<<"$out"; then echo "ok   a skill change with only a tests/ change fails"; else echo "FAIL a skill change with only a tests/ change fails: exit $rc: $out"; fail=1; fi

exit $fail
