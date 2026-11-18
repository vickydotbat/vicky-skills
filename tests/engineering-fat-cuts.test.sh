#!/usr/bin/env bash
# The engineering skills keep branch-only reference behind pointers, and the
# trimmed sentences stay gone.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
e="$root/plugins/vicky-skills/skills/engineering"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
check "gamma-shift points at its brief file, which holds the brief" 'grep -q "(BRIEF.md)" "$e/gamma-shift/SKILL.md" && grep -q "^## Subagent brief" "$e/gamma-shift/BRIEF.md" && ! grep -q "^Build <tickets>" "$e/gamma-shift/SKILL.md"'
check "sentinels points at MANUAL.md, which holds the manual pass" 'grep -q "(MANUAL.md)" "$e/sentinels/SKILL.md" && grep -q "Start from a clean tree" "$e/sentinels/MANUAL.md" && ! grep -q "Start from a clean tree" "$e/sentinels/SKILL.md"'
check "the restated sentences are gone" '! grep -q "The user can look at the same screenshots" "$e/by-eye/SKILL.md" && ! grep -q "Rebase early and often" "$e/history-monks/SKILL.md" && ! grep -q "so a reader finds the same thing" "$e/ship-it/SKILL.md" && ! grep -q "You draft them\." "$e/examples/SKILL.md"'
check "machine-spirit keeps its rules inline" 'grep -q "Status contexts are names" "$e/machine-spirit/SKILL.md" && [ ! -e "$e/machine-spirit/RULES.md" ]'
check "second-pass cuts stay gone and sharpened epigraphs stay" '! grep -q "Your pick is the answer cheapest to undo" "$e/warp/SKILL.md" && grep -q "clear, bypass or outwait every obstacle" "$e/warp/SKILL.md" && ! grep -q "lets one hide the other" "$e/review/SKILL.md" && ! grep -q "Both tools record each branch" "$e/stacked-branches/SKILL.md" && ! grep -q "health check: " "$e/spark-joy/SKILL.md" && ! grep -q "The pile.s tests already proved" "$e/marie-kondo/SKILL.md" && ! grep -q "blame the user.s copy" "$e/never-lupus/SKILL.md" && ! grep -q "hand-made rasteriser" "$e/nwn-model-tooling/SKILL.md" && ! grep -q "lists each command.s flags" "$e/nwn-model-tooling/SKILL.md" && grep -q "primary sources only" "$e/away-team/SKILL.md" && grep -q "start at step 1" "$e/lay-course/SKILL.md" && ! grep -q "misses a premise already decided" "$e/mission-brief/SKILL.md"'
check "machine-spirit drops the rule step 7 already says" '! grep -q "^- Evidence about CI comes from" "$e/machine-spirit/SKILL.md"'
exit $fail
