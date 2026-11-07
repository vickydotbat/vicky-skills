#!/usr/bin/env bash
# approved-spec: the examples approved for "over-to-you closes every find",
# ticked on a drafts page. FL1 to FL3 read the instruction that drives the
# agent; FL4 runs the Stop hook.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
s="$root/plugins/vicky-skills/skills/productivity/over-to-you/SKILL.md"
hook="$root/plugins/vicky-skills/scripts/find-ledger-guard.sh"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
ledger=$(sed -n '/^## Keep the ledger/,/^## /p' "$s")
sid="fltest-$$"; mkdir -p "/tmp/$sid"; trap 'rm -rf "/tmp/$sid" "$fx"' EXIT
fx=$(mktemp -d)
reply() { jq -nc --arg t "$1" '{type:"assistant",message:{content:[{type:"text",text:$t}]}}'; }
run() { jq -nc --arg s "$sid" --arg t "$fx/t.jsonl" '{session_id:$s,stop_hook_active:false,transcript_path:$t}' | bash "$hook" 2>/dev/null; }

# Given an over-to-you page back with items not marked [x], a quick note and a line under Other
# When the agent reads the page back
# Then before it fixes anything it writes one coded line per item, note and Other line (F1, F2, ...) into the effort's ticket
check "FL1 every find gets a line before any fix starts" \
  'grep -q "Before you fix anything, write one line per item" <<<"$ledger" && grep -q "F<n> | open" <<<"$ledger" && grep -q "per quick note and per Other line" <<<"$ledger" && grep -q "effort.s ticket" <<<"$ledger"'

# Given a ledger with lines F1 to F5
# When the agent reports that the read-back is done
# Then each of F1 to F5 is closed as fixed or handed on, with the commit, ticket or subagent, and a line left open means the read-back is not done
check "FL2 the ledger closes every line, none dropped" \
  'grep -q "Close each line as \`fixed\` with its commit, or \`handed on\` with its ticket or subagent" <<<"$ledger" && grep -q "no bug.*reason" <<<"$ledger" && grep -q "read-back is done only when no line is open" <<<"$ledger"'

# Given a ledger from the last sitting
# When the agent writes the next checklist
# Then every line closed as fixed gets an item that retests it, and every handed-on line is named on the page with where it stands
check "FL3 the next sitting retests every line that is not fixed" \
  'grep -q "every line closed as \`fixed\` an item that retests it" <<<"$ledger" && grep -q "name each \`handed on\` line on the page with where it stands" <<<"$ledger"'

# Given the agent says the over-to-you read-back is done
# And the ledger has a line with no closing word
# When the agent tries to end the turn
# Then a hook sends the turn back naming the open lines
printf 'F1 | fixed | abc123\nF2 | open | bandolier arrow\nF3 | handed on | GAME-9\n' > "/tmp/$sid/over-to-you-ledger.md"
reply "🏁 Done: read-back finished." > "$fx/t.jsonl"
out=$(run)
check "FL4 a done reply with an open line is sent back naming it" \
  '[ "$(jq -r .decision <<<"$out" 2>/dev/null)" = block ] && grep -q "F2" <<<"$out" && ! grep -q "F1" <<<"$out"'

# Given the session started over-to-you and the user closed its page with items not marked [x]
# And the agent never wrote a ledger
# When the agent reports a Done reply
# Then a hook sends the turn back asking for the ledger
rm -f "/tmp/$sid/over-to-you-ledger.md"
printf '# Over to you\n1. [x] a\n2. [-] b\n' > "/tmp/$sid/over-to-you-test.md"
reply "🏁 Done: finished." > "$fx/t.jsonl"
out=$(run)
check "FL5 skipping the ledger is caught" \
  '[ "$(jq -r .decision <<<"$out" 2>/dev/null)" = block ] && grep -q "ledger" <<<"$out"'
rm -f "/tmp/$sid/over-to-you-test.md"

# Given a ledger with an open line
# When the agent ends its turn with a reply that claims the work is finished without a Done line
# Then the turn is still held
printf 'F1 | open | a\n' > "/tmp/$sid/over-to-you-ledger.md"
reply "All fixed, nothing left." > "$fx/t.jsonl"
out=$(run)
check "FL6 a done claim without a Done line is still held" \
  '[ "$(jq -r .decision <<<"$out" 2>/dev/null)" = block ] && grep -q "F1" <<<"$out"'

# Given a ledger line closed as no bug with a reason
# Then it counts as closed
# Given a ledger line closed as no bug with no reason
# Then the hook holds the done reply and names it
printf 'F1 | no bug | the item was identified\n' > "/tmp/$sid/over-to-you-ledger.md"
reply "🏁 Done: finished." > "$fx/t.jsonl"
check "FL7 a no-bug line with a reason is closed" '[ -z "$(run)" ]'
printf 'F1 | no bug | the item was identified\nF2 | no bug |\n' > "/tmp/$sid/over-to-you-ledger.md"
out=$(run)
check "FL7 a no-bug line with no reason is held and named" \
  '[ "$(jq -r .decision <<<"$out" 2>/dev/null)" = block ] && grep -q "F2" <<<"$out" && ! grep -q "F1" <<<"$out"'
exit $fail
