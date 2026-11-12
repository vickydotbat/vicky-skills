#!/usr/bin/env bash
# approved-spec: the examples approved for "over-to-you closes every find",
# ticked on a drafts page. FL1 to FL3 read the instruction that drives the
# agent.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
s="$root/plugins/vicky-skills/skills/productivity/over-to-you/SKILL.md"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
ledger=$(sed -n '/^## Keep the ledger/,/^## /p' "$s")

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

exit $fail
