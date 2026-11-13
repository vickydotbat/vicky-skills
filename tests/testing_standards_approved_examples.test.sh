#!/usr/bin/env bash
# approved-spec: the examples approved on the star "Every repo has a
# TESTING_STANDARDS.md", reworded when the Testing standards: line came in. Each check is named after its example and reads the
# instructions that drive the agent.
set -u
p="$(dirname "$0")/../plugins/vicky-skills"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
reads=0
for f in productivity/over-to-you engineering/do engineering/sentinels engineering/review engineering/make-it-so; do
  grep -q "Read the repo's testing standards first, where the \`Testing standards:\` line" "$p/skills/$f/SKILL.md" && reads=$((reads + 1)) || echo "     $f"
done
check "in a repo whose Testing standards: line names where its testing standards live, every testing skill reads them first and follows them over its own defaults" \
  '[ $reads = 5 ] && grep -q "they win over this skill" "$p/skills/engineering/do/SKILL.md"'
fc="$p/skills/engineering/first-contact"
check "in a repo with no testing standards, first-contact writes them from what it finds, asks about what it can't find, and writes the Testing standards: line that points at them" \
  'grep -q "write \`Testing standards: TESTING_STANDARDS.md\`" "$fc/SKILL.md" && grep -q "ask the user about each line it can'"'"'t fill" "$fc/SKILL.md" && [ -f "$fc/testing-standards.md" ] && grep -q "^Test surface:" "$fc/testing-standards.md" && grep -q "^Commit test cruft: no" "$fc/testing-standards.md"'
check "on a pull request, the standards reviewer holds its tests and test kits to the testing standards the Testing standards: line names" \
  'grep -q "the testing standards the \`Testing standards:\` line names" "$p/agents/standards-reviewer.md" && grep -q "tests and test kits" "$p/agents/standards-reviewer.md"'
check "in a repo whose testing standards say test cruft may be committed, and where, over-to-you may commit a kit there and only there" \
  'grep -q "commit it there and only there" "$p/skills/productivity/over-to-you/SKILL.md"'
exit $fail
