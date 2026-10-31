#!/usr/bin/env bash
# approved-spec: the examples approved for "over-to-you gives each section
# quick-fire note categories", approved in the user's editor. Each check is
# named after its example. The behaviour is the agent's, so each check reads
# the instruction that drives it.
set -u
s="$(dirname "$0")/../plugins/vicky-skills/skills/productivity/over-to-you/SKILL.md"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
form=$(sed -n '/^## Form/,$p' "$s")
notes=$(sed -n '/^## Quick notes/,/^## /p' "$s")
section=$(sed -n '/^## <section>/,/^## Extra tests/p' <<<"$form")
check "a section of the checklist, when over-to-you writes it, ends with a quick-notes block holding every category, each blank" \
  'grep -q "^quick notes:" <<<"$section" && for c in BUG QUIRK FRICTION UGLY IDEA RULE WIP QUESTION; do grep -qx -- "- $c:" <<<"$section" || exit 1; done'
check "a quick note tagged IDEA, on read-back, becomes a ticket on the right map, and the report names it" \
  'grep -q "^| IDEA |.*ticket on the right map.*report names it" <<<"$notes" && grep "Read it back" "$s" | grep -q "Quick notes"'
check "a quick note tagged RULE, on read-back, is engraved the strongest way that fits, and the report says where" \
  'grep -q "^| RULE |.*\`engrave\`.*strongest way that fits.*report says where" <<<"$notes"'
check "a quick-notes block left blank, on read-back, records nothing for that section beyond its items' marks" \
  'grep -q "A blank quick-notes block records nothing beyond its items'"'"' marks" <<<"$notes"'
check "when an over-to-you opens, the top of the page has a brief saying what the sitting is for and what the quick-notes tags mean" \
  'head -8 <<<"$form" | grep -q "<brief: what this sitting is for" && head -8 <<<"$form" | grep -q "what each quick-notes tag means"'
exit $fail
