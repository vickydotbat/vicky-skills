#!/usr/bin/env bash
# approved-spec: the examples the user asked for, relayed from another
# session: an over-to-you checklist covers the whole branch, minus recorded
# sign-offs. Reads the instruction that drives the agent.
set -u
s="$(dirname "$0")/../plugins/vicky-skills/skills/productivity/over-to-you/SKILL.md"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
step() { awk -v n="$1" '$0 ~ "^"n"\\. "{on=1; print; next} /^[0-9]+\. /{on=0} /^## /{on=0} on' "$s"; }
check "a branch naming eighteen tickets gets a checklist where every ticket and changed feature area has an item, a recorded sign-off, or a reason no person can check it" \
  'step 1 | grep -q "the whole branch" && step 1 | grep -q "every ticket the branch, its commits or its pull request body names" && step 1 | grep -q "every ticket and changed feature area has an item, a recorded sign-off, or a reason no person can check it"'
check "an item already passed, with its sign-off on the Proof section, a ticket comment or an earlier over-to-you file, is left out and the opening names where it is recorded" \
  'step 1 | grep -q "Proof section, a ticket comment, or an earlier over-to-you file" && grep -q "signed off:" "$s"'
check "more than seven items become numbered sittings of seven or fewer, and none is dropped" \
  'step 3 | grep -q "numbered sittings" && step 3 | grep -q "none is dropped" && ! grep -q "split a longer list into two sittings" "$s"'
exit $fail
