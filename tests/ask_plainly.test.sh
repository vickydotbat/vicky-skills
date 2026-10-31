#!/usr/bin/env bash
# A question to the user says what the thing does and how to answer, and an
# approved-test draft section carries an approve box. Reads the instructions
# that drive the agent.
set -u
p="$(dirname "$0")/../plugins/vicky-skills"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
check "a question to the user opens with what the thing does, and says how to answer" \
  'sed -n "/^## Decisions/,/^## /p" "$p/output-styles/dungeon-master.md" | grep -q "A question to the user opens with what the thing does, in one plain line" && grep -q "Say how they answer" "$p/output-styles/dungeon-master.md"'
check "a red-pen section for an approved test holds an approve box to tick" \
  'grep -qF -- "holds \`- [ ] approve\` on the line under its location" "$p/skills/productivity/red-pen/SKILL.md" && grep -qF -- "holds \`- [ ] approve\` on the line under its location" "$p/skills/engineering/examples/SKILL.md"'
exit $fail
