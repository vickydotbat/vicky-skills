#!/usr/bin/env bash
# A branch that changes a skill's text also changes a test that proves the
# change works as intended. This check holds the floor (some file under tests/
# changed). AGENTS.md's "Change a skill" rule holds the rest: the test goes red
# on the skill text before the change. A local run needs `git fetch origin`.
set -u
cd "$(dirname "$0")/.."
# judge reads changed paths on stdin. It exits 1, naming the skill files, when
# skill text changed and no test did.
judge() {
  local files skills
  files=$(cat)
  skills=$(printf '%s\n' "$files" | grep -E '^plugins/vicky-skills/skills/.+\.md$')
  [ -z "$skills" ] && return 0
  printf '%s\n' "$files" | grep -qE '^tests/' && return 0
  echo "skill text changed with no test: add or change a test under tests/ that fails on the old text and passes on the new (AGENTS.md, Change a skill):"
  printf '  %s\n' $skills
  return 1
}
fail=0
case_() { printf '%b' "$3" | judge >/dev/null; [ $? -eq "$2" ] || { echo "FAIL $1"; fail=1; }; }
case_ "no change passes" 0 ""
case_ "a skill change with a test passes" 0 'plugins/vicky-skills/skills/engineering/do/SKILL.md\ntests/do.test.sh\n'
case_ "a skill change alone fails" 1 'plugins/vicky-skills/skills/engineering/do/SKILL.md\n'
case_ "a skill's side file alone fails" 1 'plugins/vicky-skills/skills/engineering/decision-record/FORMAT.md\n'
case_ "a README change alone passes" 0 'README.md\n'
case_ "a skill script change alone passes (its own test rules hold it)" 0 'plugins/vicky-skills/skills/engineering/decision-record/scripts/check-adr.sh\n'
[ $fail -eq 0 ] || exit 1
base=$(git merge-base HEAD origin/main 2>/dev/null) || { echo "skill-change-tested: no origin/main to compare with: run git fetch origin"; exit 1; }
git diff --name-only "$base" HEAD | judge || exit 1
echo "ok   skill-change-tested: every skill text change on this branch comes with a test change"
