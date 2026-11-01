#!/usr/bin/env bash
# cerebro builds the proposals it would pick, unasked, and asks only about
# one a wrong guess would make expensive to undo.
set -u
cer="$(dirname "$0")/../plugins/vicky-skills/skills/productivity/cerebro/SKILL.md"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
six=$(awk '/^6\. /{on=1} /^7\. /{on=0} on' "$cer")
check "step 6 assumes the yes and builds the picks this turn" 'grep -q "assume the yes" <<<"$six" && grep -q "Build every proposal you would pick in this turn" <<<"$six"'
check "step 6 asks only when a wrong guess is expensive to undo" 'grep -q "Ask first only for a proposal a wrong guess would make expensive to undo" <<<"$six"'
check "the template no longer ends on a bare ask for the pick" '! grep -q "I.d take C1. Want it?" "$cer"'
exit $fail
