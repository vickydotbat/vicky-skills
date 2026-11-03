#!/usr/bin/env bash
# The skill lines the RGB colour sittings taught (debt log D18, D22, D23, D27,
# D28, D33, D34, D36): each lesson sits in the step of the skill that acts on
# it, so the next sitting reads it at the moment it applies.
set -u
skills="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/skills"
fail=0
# has <name> <skill file> <step heading prefix or "-"> <phrase>: the phrase sits
# in that step's line (or anywhere in the file with "-").
has() {
  local text
  if [ "$3" = - ]; then text=$(cat "$skills/$2"); else text=$(grep -F -- "$3" "$skills/$2"); fi
  if grep -qiF -- "$4" <<<"$text"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi
}
oty=productivity/over-to-you/SKILL.md
has "a hand check opens its page in the turn the code lands (D22)" engineering/do/SKILL.md "5. **Run the checks" "start \`over-to-you\` in the same turn"
has "each expected result is checked against the stated rules (D23)" $oty "3. **Write the checklist**" "against the rules the user stated"
has "a feel item with a measurable proxy is measured first (D27)" $oty "1. **Pick the human-only checks" "measurable proxy"
has "a retest's test reaches the layer that failed, or names the gap (D33)" $oty "1. **Pick the human-only checks" "the layer the user saw fail"
has "an item failed twice goes to never-lupus before a third sitting (D34)" $oty "5. **Read it back.**" "fails a second time"
has "a platform limit report gives the headroom (D18)" engineering/never-lupus/SKILL.md "4. **Test one prediction" "headroom under normal use"
has "engrave takes a platform limit unasked (D18)" engineering/engrave/SKILL.md - "platform limit"
has "a workbench proof becomes a test in the shipping repo (D28)" engineering/do/SKILL.md "5. **Run the checks" "outside the repo that ships"
has "a recommendation on a store's state reads the store first (D36)" engineering/do/SKILL.md "- **Questions**" "reads that store first"
exit $fail
