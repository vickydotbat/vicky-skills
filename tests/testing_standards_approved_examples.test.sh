#!/usr/bin/env bash
# approved-spec: the examples approved on the star "Every repo has a
# TESTING_STANDARDS.md". Each check is named after its example and reads the
# instructions that drive the agent.
set -u
p="$(dirname "$0")/../plugins/vicky-skills"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
reads=0
for f in productivity/over-to-you engineering/do engineering/sentinels engineering/placebo engineering/review engineering/make-it-so; do
  grep -q "Read the repo's \`TESTING_STANDARDS.md\` first" "$p/skills/$f/SKILL.md" && reads=$((reads + 1)) || echo "     $f"
done
check "in a repo with a TESTING_STANDARDS.md, every testing skill reads it first and follows it over its own defaults" \
  '[ $reads = 6 ] && grep -q "it wins over this skill" "$p/skills/engineering/do/SKILL.md"'
fc="$p/skills/engineering/first-contact"
check "in a repo without one, first-contact writes one from what it finds and asks about what it can't find" \
  'grep -q "TESTING_STANDARDS.md" "$fc/SKILL.md" && grep -q "ask the user about each line it can'"'"'t fill" "$fc/SKILL.md" && [ -f "$fc/testing-standards.md" ] && grep -q "^Test surface:" "$fc/testing-standards.md" && grep -q "^Commit test cruft: no" "$fc/testing-standards.md"'
check "on a pull request, the standards reviewer holds its tests and test kits to TESTING_STANDARDS.md" \
  'grep -q "TESTING_STANDARDS.md" "$p/agents/standards-reviewer.md" && grep -q "tests and test kits" "$p/agents/standards-reviewer.md"'
check "in a repo whose file says test cruft may be committed, and where, over-to-you may commit a kit there and only there" \
  'grep -q "commit it there and only there" "$p/skills/productivity/over-to-you/SKILL.md"'
exit $fail
