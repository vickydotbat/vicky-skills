#!/usr/bin/env bash
# The engineering skills keep branch-only reference behind pointers, and the
# trimmed sentences stay gone.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
e="$root/plugins/vicky-skills/skills/engineering"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
check "gamma-shift points at its brief file, which holds the brief" 'grep -q "(BRIEF.md)" "$e/gamma-shift/SKILL.md" && grep -q "^## Subagent brief" "$e/gamma-shift/BRIEF.md" && ! grep -q "^Build <tickets>" "$e/gamma-shift/SKILL.md"'
check "machine-spirit points at RULES.md, which holds the rules" 'grep -q "(RULES.md)" "$e/machine-spirit/SKILL.md" && grep -q "Status contexts are names" "$e/machine-spirit/RULES.md" && ! grep -q "Status contexts are names" "$e/machine-spirit/SKILL.md"'
check "sentinels points at MANUAL.md, which holds the manual pass" 'grep -q "(MANUAL.md)" "$e/sentinels/SKILL.md" && grep -q "Start from a clean tree" "$e/sentinels/MANUAL.md" && ! grep -q "Start from a clean tree" "$e/sentinels/SKILL.md"'
check "the restated sentences are gone" '! grep -q "The user can look at the same screenshots" "$e/by-eye/SKILL.md" && ! grep -q "Rebase early and often" "$e/history-monks/SKILL.md" && ! grep -q "so a reader finds the same thing" "$e/ship-it/SKILL.md" && ! grep -q "You draft them\." "$e/examples/SKILL.md"'
exit $fail
