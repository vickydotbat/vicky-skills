#!/usr/bin/env bash
# approved-spec: the examples approved for "after an over-to-you, the agent
# fixes small finds and hands big ones to a clean context", ticked on a
# drafts page. Each check is named after its example. The behaviour is the
# agent's, so each check reads the instruction that drives it.
set -u
s="$(dirname "$0")/../plugins/vicky-skills/skills/productivity/over-to-you/SKILL.md"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
sized=$(sed -n '/^## Size the finds/,/^## Kits/p' "$s")
step5=$(grep '^5\. \*\*Read it back' "$s")

# Given a failed item whose fix touches one file and needs one test
# When the agent reads the page back
# Then the agent fixes it in that session and its report says so
check "SF1 a small find is fixed in place" \
  'grep -q "small.*one file.*one test" <<<"$sized" && grep -q "small find.*fix it in that session" <<<"$sized" && grep -q "Size the finds" <<<"$step5"'

# Given a failed item whose fix touches more than one file, or needs more than one test
# When the agent reads the page back
# Then the agent writes the find, its cause so far and the state of the work into the effort's ticket, and does not start the fix in that session
check "SF2 a big find is written down and not fixed in this session" \
  'grep -q "big.*more than one file.*more than one test" <<<"$sized" && grep -q "big find.*ticket.*cause so far.*state of the work" <<<"$sized" && grep -q "big find.*start no fix" <<<"$sized"'

# Given a big find written into the ticket
# When the agent hands it on
# Then it starts one subagent with a clean context, tells it to read the ticket whole and gives it the exact commands, and its report names the subagent
check "SF3 a big find goes to a subagent with a clean context" \
  'grep -q "one subagent with a clean context" <<<"$sized" && grep -q "read the ticket whole" <<<"$sized" && grep -q "exact commands" <<<"$sized" && grep -q "report names the subagent" <<<"$sized"'

# Given a big find written into the ticket
# And the agent cannot start a subagent (it is one itself)
# When the agent hands it on
# Then it asks the user to type /conn, names the ticket, and starts no fix
check "SF4 with no subagent to start, the agent asks for /conn" \
  'grep -q "cannot start a subagent.*ask the user to type \`/conn\`" <<<"$sized" && grep -q "name the ticket" <<<"$sized"'

# Given a quick note tagged IDEA, RULE, WIP or QUESTION
# When the agent reads the page back
# Then it handles the note as the Quick notes table says, whatever its size
# Given an item that fails a second time
# When the agent reads the page back
# Then it goes to never-lupus as before, even when the fix looks small
check "SF5 the size rule covers fixes only, so quick notes and a second failure keep their rules" \
  'grep -q "IDEA, RULE, WIP and QUESTION notes keep the Quick notes table" <<<"$sized" && grep -q "fails a second time.*never-lupus.*even when the fix looks small" <<<"$sized"'

# Given an over-to-you page back with several finds
# When the agent reports
# Then the report lists each find with one word, fixed or handed on, and the ticket or subagent that holds the handed-on ones
check "SF6 the report lists each find and where it went" \
  'grep -q "lists each find.*fixed.*handed on.*ticket or subagent" <<<"$sized"'
exit $fail
