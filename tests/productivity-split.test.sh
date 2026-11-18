#!/usr/bin/env bash
# The long productivity skills keep their steps in SKILL.md and their
# branch-only reference in a sibling file behind a pointer. Each pointer
# resolves, and each moved section sits in its new home and not the old one.
set -u
cd "$(dirname "$0")/../plugins/vicky-skills/skills"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

check "over-to-you keeps Kits, Quick notes and Form in REFERENCE.md" \
  'grep -q "^## Kits" building/over-to-you/REFERENCE.md && grep -q "^## Quick notes" building/over-to-you/REFERENCE.md && grep -q "^## Form" building/over-to-you/REFERENCE.md && ! grep -qE "^## (Kits|Quick notes|Form)" building/over-to-you/SKILL.md'
check "over-to-you steps point at REFERENCE.md" \
  'grep -q "REFERENCE.md" building/over-to-you/SKILL.md && grep -q "^## Keep the ledger" building/over-to-you/SKILL.md && grep -q "^## Size the finds" building/over-to-you/SKILL.md'
check "over-to-you stage step names its dry run and its retest" \
  'grep -q "\*\*Dry run.\*\*" building/over-to-you/SKILL.md && grep -q "\*\*Retest.\*\*" building/over-to-you/SKILL.md'
check "human-voice keeps its moves in MOVES.md behind two pointers" \
  'grep -q "^\*\*Words\*\*" writing/human-voice/MOVES.md && ! grep -q "^## Moves" writing/human-voice/SKILL.md && [ "$(grep -c "(MOVES.md)" writing/human-voice/SKILL.md)" -ge 2 ]'
check "human-voice opens with the ghostwrite leading word" \
  'grep -q "^Ghostwrite:" writing/human-voice/SKILL.md'
check "council-of-elrond keeps its seat table and closing form in sibling files" \
  'grep -q "^| \*\*Boromir\*\*" planning/council-of-elrond/SEATS.md && grep -q "^\*\*Frodo:\*\* I will take it" planning/council-of-elrond/CLOSE.md && ! grep -q "^| Seat | Angle |" planning/council-of-elrond/SKILL.md && grep -q "(SEATS.md)" planning/council-of-elrond/SKILL.md && grep -q "(CLOSE.md)" planning/council-of-elrond/SKILL.md'
check "red-pen reads the close once" \
  '[ "$(grep -c "never start a watch after it" writing/red-pen/SKILL.md)" = 1 ]'
check "cerebro keeps its forecast reads in one sentence" \
  'grep -q "For a forecast, also read the open tickets and pull requests the work touched, and run" housekeeping/cerebro/SKILL.md'
exit $fail
