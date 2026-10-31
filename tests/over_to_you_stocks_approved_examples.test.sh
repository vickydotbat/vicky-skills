#!/usr/bin/env bash
# approved-spec: the examples approved on the star "over-to-you stocks the test
# before handing it over". Each check is named after its example. The
# behaviour is the agent's, so each check reads the instruction that drives it.
set -u
s="$(dirname "$0")/../plugins/vicky-skills/skills/productivity/over-to-you/SKILL.md"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
step() { awk -v n="$1" '$0 ~ "^"n"\\. "{on=1; print; next} /^[0-9]+\. /{on=0} /^## /{on=0} on' "$s"; }
stage=$(step 2)
check "a check that needs props I don't have gets them made, or one command that makes them, and I never build one by hand" \
  'grep -q "Stock every item" <<<"$stage" && grep -q "the one command that makes them" <<<"$stage" && grep -q "never builds a prop by hand" <<<"$stage"'
check "a project whose docs name a test surface, such as a test module or a seed script, gets every prop there, by the means the docs describe" \
  'grep -q "the means the project'"'"'s docs describe" <<<"$stage" && grep -q "Test props:" <<<"$stage"'
check "a project whose docs name no place for test props gets something disposable, removed after, and I am asked where props live from now on" \
  'grep -q "disposable" <<<"$stage" && grep -q "remove it after the sitting" <<<"$stage" && grep -q "ask the user where test props live" <<<"$stage"'
check "a prop that would land in content that ships goes to the test surface or a disposable instead" \
  'grep -q "never in content that ships" <<<"$stage"'
exit $fail
