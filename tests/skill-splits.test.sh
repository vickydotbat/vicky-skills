#!/usr/bin/env bash
# The long skills keep their steps in SKILL.md and their branch-only
# reference behind a pointer, short reference stays inline, and the
# sentences the trims cut stay gone.
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
check "red-pen reads the close once" \
  '[ "$(grep -c "never start a watch after it" writing/red-pen/SKILL.md)" = 1 ]'
check "cerebro keeps its forecast reads in one sentence" \
  'grep -q "For a forecast, also read the open tickets and pull requests the work touched, and run" housekeeping/cerebro/SKILL.md'
check "the restated sentences are gone" '! grep -q "The user can look at the same screenshots" "building/by-eye/SKILL.md" && ! grep -q "Rebase early and often" "shipping/history-monks/SKILL.md" && ! grep -q "so a reader finds the same thing" "shipping/ship-it/SKILL.md" && ! grep -q "You draft them\." "planning/examples/SKILL.md"'
check "second-pass cuts stay gone and sharpened epigraphs stay" '! grep -q "Your pick is the answer cheapest to undo" "building/warp/SKILL.md" && grep -q "clear, bypass or outwait every obstacle" "building/warp/SKILL.md" && ! grep -q "lets one hide the other" "shipping/review/SKILL.md" && ! grep -q "Both tools record each branch" "building/stacked-branches/SKILL.md" && ! grep -q "health check: " "building/spark-joy/SKILL.md" && ! grep -q "The pile.s tests already proved" "housekeeping/marie-kondo/SKILL.md" && ! grep -q "blame the user.s copy" "building/never-lupus/SKILL.md" && ! grep -q "hand-made rasteriser" "building/nwn-model-tooling/SKILL.md" && ! grep -q "lists each command.s flags" "building/nwn-model-tooling/SKILL.md" && grep -q "primary sources only" "planning/away-team/SKILL.md" && grep -q "start at step 1" "commands/lay-course/SKILL.md" && ! grep -q "misses a premise already decided" "planning/mission-brief/SKILL.md"'
check "machine-spirit drops the rule step 7 already says" '! grep -q "^- Evidence about CI comes from" "building/machine-spirit/SKILL.md"'
check "gamma-shift, sentinels and council-of-elrond keep their short reference inline" \
  'grep -q "^## Subagent brief" housekeeping/gamma-shift/SKILL.md && grep -q "^Build <tickets>" housekeeping/gamma-shift/SKILL.md && grep -q "Start from a clean tree" building/sentinels/SKILL.md && grep -q "^| \*\*Boromir\*\*" planning/council-of-elrond/SKILL.md && grep -q "^## Closing reply" planning/council-of-elrond/SKILL.md && ! ls housekeeping/gamma-shift/BRIEF.md building/sentinels/MANUAL.md planning/council-of-elrond/SEATS.md planning/council-of-elrond/CLOSE.md 2>/dev/null | grep -q .'
check "first-contact names no skill group" '! grep -qi "engineering skills" commands/first-contact/SKILL.md'
check "sentinels leaves the memory cap to the session" 'grep -q "needs no cap of its own" building/sentinels/SKILL.md'
check "red-pen names the background notice as the close" 'grep -q "completed with exit code 0 is the close" writing/red-pen/SKILL.md'
exit $fail
