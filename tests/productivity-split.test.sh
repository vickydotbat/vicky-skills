#!/usr/bin/env bash
# The long productivity skills keep their steps in SKILL.md and their
# branch-only reference in a sibling file behind a pointer. Each pointer
# resolves, and each moved section sits in its new home and not the old one.
set -u
cd "$(dirname "$0")/../plugins/vicky-skills/skills/productivity"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

check "over-to-you keeps Kits, Quick notes and Form in REFERENCE.md" \
  'grep -q "^## Kits" over-to-you/REFERENCE.md && grep -q "^## Quick notes" over-to-you/REFERENCE.md && grep -q "^## Form" over-to-you/REFERENCE.md && ! grep -qE "^## (Kits|Quick notes|Form)" over-to-you/SKILL.md'
check "over-to-you steps point at REFERENCE.md" \
  'grep -q "REFERENCE.md" over-to-you/SKILL.md && grep -q "^## Keep the ledger" over-to-you/SKILL.md && grep -q "^## Size the finds" over-to-you/SKILL.md'
check "over-to-you stage step names its dry run and its retest" \
  'grep -q "\*\*Dry run.\*\*" over-to-you/SKILL.md && grep -q "\*\*Retest.\*\*" over-to-you/SKILL.md'
check "human-voice keeps its moves in MOVES.md behind two pointers" \
  'grep -q "^\*\*Words\*\*" human-voice/MOVES.md && ! grep -q "^## Moves" human-voice/SKILL.md && [ "$(grep -c "(MOVES.md)" human-voice/SKILL.md)" -ge 2 ]'
check "human-voice opens with the ghostwrite leading word" \
  'grep -q "^Ghostwrite:" human-voice/SKILL.md'
check "council-of-elrond keeps its seat table and closing form in sibling files" \
  'grep -q "^| \*\*Boromir\*\*" council-of-elrond/SEATS.md && grep -q "^\*\*Frodo:\*\* I will take it" council-of-elrond/CLOSE.md && ! grep -q "^| Seat | Angle |" council-of-elrond/SKILL.md && grep -q "(SEATS.md)" council-of-elrond/SKILL.md && grep -q "(CLOSE.md)" council-of-elrond/SKILL.md'
check "red-pen reads the close once" \
  '[ "$(grep -c "never start a watch after it" red-pen/SKILL.md)" = 1 ]'
check "cerebro keeps its forecast reads in one sentence" \
  'grep -q "For a forecast, also read the open tickets and pull requests the work touched, and run" cerebro/SKILL.md'
exit $fail
