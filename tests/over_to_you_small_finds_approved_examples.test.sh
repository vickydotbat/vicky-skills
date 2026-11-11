#!/usr/bin/env bash
# approved-spec: the examples approved for "an over-to-you read-back fixes
# nothing and ends the session with /conn", ticked on a drafts page. Each
# check is named after its example. The behaviour is the agent's, so each
# check reads the instruction that drives it, or runs the hook that holds it.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
s="$here/../plugins/vicky-skills/skills/productivity/over-to-you/SKILL.md"
hook="$here/../plugins/vicky-skills/scripts/find-ledger-guard.sh"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
sized=$(sed -n '/^## Size the finds/,/^## Keep the ledger/p' "$s")
step5=$(grep '^5\. \*\*Read it back' "$s")
step6=$(grep '^6\. \*\*End the session' "$s")

# Given a failed item whose fix touches one file and needs one test
# When the agent reads the page back
# Then it writes the find on the ticket, sized small, and fixes nothing in that session
check "SF1 a small find goes on the ticket" \
  'grep -q "small\*\* find has a fix in one file that needs one test" <<<"$sized" && grep -q "every find is fixed in a later session" <<<"$sized" && grep -q "Fix nothing" <<<"$step5"'

# Given a failed item whose fix touches more than one file, or needs more than one test
# When the agent reads the page back
# Then it writes the find, its cause so far and the state of the work on the ticket, sized big, and fixes nothing in that session
check "SF2 a big find goes on the ticket" \
  'grep -q "big\*\*: its fix touches more than one file, or needs more than one test" <<<"$sized" && grep -q "ticket with its cause so far" <<<"$step5" && grep -q "Size each find on its ticket line" <<<"$sized"'

# Given a read-back with every find on the ticket
# When the agent ends the read-back
# Then it writes the pull request's Status, asks the user to type /conn and start a fresh session, and starts no fix and no subagent
check "SF3 the read-back ends the session" \
  'grep -q "Status section" <<<"$step6" && grep -q "type \`/conn\` and start a fresh session" <<<"$step6" && grep -q "Start no test, fix or build" <<<"$step6" && ! grep -q "subagent" <<<"$sized"'

# Given a page the user has marked
# And the user has not typed /conn
# When the agent ends a turn without asking for /conn
# Then a hook sends the turn back
sid="sf-$$"; fx=$(mktemp -d); mkdir -p "/tmp/$sid"; trap 'rm -rf "$fx" "/tmp/$sid"' EXIT
printf '1. [x] a\n' > "/tmp/$sid/over-to-you-p.md"
jq -nc '{type:"assistant",message:{content:[{type:"text",text:"Fixing F1 now."}]}}' > "$fx/t.jsonl"
out=$(jq -nc --arg s "$sid" --arg t "$fx/t.jsonl" '{session_id:$s,stop_hook_active:false,transcript_path:$t}' | env -u CLAUDE_PLUGIN_OPTION_GUARD_FIND_LEDGER bash "$hook" 2>/dev/null)
check "SF4 a reply that skips /conn is sent back" \
  '[ "$(jq -r .decision <<<"$out" 2>/dev/null)" = block ] && grep -q "/conn" <<<"$out"'

# Given a quick note tagged IDEA, RULE, WIP or QUESTION
# When the agent reads the page back
# Then it handles the note as the Quick notes table says, whatever its size
# Given an item that fails a second time
# When the agent reads the page back
# Then its ticket line sends it to never-lupus in the next session
check "SF5 quick notes and a second failure keep their rules" \
  'grep -q "IDEA, RULE, WIP and QUESTION notes keep the Quick notes table, whatever their size" <<<"$sized" && grep -q "never-lupus. alone for an item that fails a second time" <<<"$step5"'

# Given an item whose notes line asks for an action, such as putting it on the hand-test ticket or finding an integration test
# When the agent reads the page back
# Then it does what the note asks for that item, before any default step
check "SF6 an item's own note is its instruction" \
  'grep -q "First act on each item.s own .notes:. line" <<<"$step5" && grep -q "outranks every default" <<<"$step5"'

# Given a page back with several finds
# When the agent reports
# Then the report lists each find with its size and the ticket that holds it
check "SF7 the report lists each find and where it went" \
  'grep -q "report lists each find with its size and the ticket that holds it" <<<"$sized"'
exit $fail
