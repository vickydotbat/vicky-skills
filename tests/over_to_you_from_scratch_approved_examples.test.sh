#!/usr/bin/env bash
# approved-spec: the examples approved on the star "over-to-you builds each
# test from scratch and cleans up". Each check is named after its example. The
# behaviour is the agent's, so each check reads the instruction that drives it.
set -u
s="$(dirname "$0")/../plugins/vicky-skills/skills/productivity/over-to-you/SKILL.md"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
kits=$(sed -n '/^## Kits/,/^## /p' "$s")
form=$(sed -n '/^## Form/,$p' "$s")
check "a check that needs a creature to act on gets a new one spawned and set up for it, never one borrowed from the world" \
  'grep -q "Build each check its own things, from scratch" <<<"$kits" && grep -q "never borrow one already in the world" <<<"$kits"'
check "an existing creature that might be hostile, busy or changed is passed over for one the kit builds, since a borrowed one makes the check flaky" \
  'grep -q "Reuse only what you already know works" <<<"$kits" && grep -q "flaky" <<<"$kits"'
check "a kit whose things could combine, such as stacks that merge in a pack, finishes each thing before it reaches the place where it could combine" \
  'grep -q "Finish each thing (its properties set, its locals written) before it reaches the place where it could combine" <<<"$kits"'
check "when the sitting closes, everything the kits made is removed and no kit file is committed, unless the project's docs allow it and say where" \
  'grep -q "remove everything the kits made" <<<"$kits" && grep -q "commit no kit file" <<<"$kits" && grep -q "unless TESTING_STANDARDS.md allows it and says where" <<<"$kits" && grep "Read it back" "$s" | grep -q "Kits"'
check "the checklist marks each item [x] completed as expected, [~] completed with changes, [-] failed to complete, or [ ] not tested, in sections, and ends with Extra tests and Other" \
  'grep -qF "[x] completed as expected" <<<"$form" && grep -qF "[~] completed with changes" <<<"$form" && grep -qF "[-] failed to complete" <<<"$form" && grep -qF "[ ] not tested at all" <<<"$form" && grep -q "^## <section>" <<<"$form" && grep -q "^## Extra tests" <<<"$form" && grep -q "^## Other" <<<"$form"'
exit $fail
