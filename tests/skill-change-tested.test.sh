#!/usr/bin/env bash
# A branch that changes a skill's text also changes an eval case that proves
# the change works as intended. scripts/skill-change-proven.sh holds the floor
# (some eval case changed). AGENTS.md's "Change a skill" rule holds the rest:
# the case fails on the skill text before the change. A local run needs
# `git fetch origin`.
set -u
cd "$(dirname "$0")/.."
judge=plugins/vicky-skills/scripts/skill-change-proven.sh
fail=0
case_() { printf '%b' "$3" | bash "$judge" >/dev/null; [ $? -eq "$2" ] || { echo "FAIL $1"; fail=1; }; }
case_ "no change passes" 0 ""
case_ "a skill change with an eval case passes" 0 'plugins/vicky-skills/skills/building/do/SKILL.md\nplugins/vicky-skills/evals/do/a-case/prompt.md\n'
case_ "a skill change with only a test fails" 1 'plugins/vicky-skills/skills/building/do/SKILL.md\ntests/do.test.sh\n'
case_ "a skill change alone fails" 1 'plugins/vicky-skills/skills/building/do/SKILL.md\n'
case_ "a skill's side file alone fails" 1 'plugins/vicky-skills/skills/planning/decision-record/FORMAT.md\n'
case_ "a README change alone passes" 0 'README.md\n'
case_ "a skill script change alone passes (its own test rules hold it)" 0 'plugins/vicky-skills/skills/planning/decision-record/scripts/check-adr.sh\n'
[ $fail -eq 0 ] || exit 1
base=$(git merge-base HEAD origin/main 2>/dev/null) || { echo "skill-change-tested: no origin/main to compare with: run git fetch origin"; exit 1; }
git diff --name-only "$base" HEAD | bash "$judge" || exit 1
echo "ok   skill-change-tested: every skill text change on this branch comes with an eval case change"
