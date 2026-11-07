#!/usr/bin/env bash
# Stop hook (guard_find_ledger, on by default): an over-to-you read-back is
# done only when every find in its ledger is closed. The ledger is
# over-to-you-ledger.md in the session scratch folder, one line per find as
# `F<n> | open|fixed|handed on|no bug | <ref or reason>`. While a line is open,
# or a `no bug` line has no reason, the turn is sent back once unless its
# reply opens with "🚪 Waiting on you:" or it left something running that
# wakes the session. A "🏁 Done:" reply with no ledger, after a checklist page
# of this session was closed with an item not marked [x], is sent back to
# write one. A second stop, a missing tool and the setting off pass.
set -u
case "${CLAUDE_PLUGIN_OPTION_GUARD_FIND_LEDGER:-}" in false|0) exit 0 ;; esac
command -v jq >/dev/null || exit 0 # mutant-ok delete: without the tool every later read comes back empty, and the hook exits 0 the same way
# shellcheck source=stop-reply.sh
. "$(dirname "$0")/stop-reply.sh"
sid=$(jq -r '.session_id // ""' <<<"$payload" 2>/dev/null)
dir="/tmp/$sid"
ledger="$dir/over-to-you-ledger.md"
send() { jq -n --arg r "$1" '{decision:"block", reason:$r}'; exit 0; }
if [[ -f "$ledger" ]]; then
  open=$(grep -E '^F[0-9]+[[:space:]]*\|[[:space:]]*(open([[:space:]]|\|)|no bug[[:space:]]*\|[[:space:]]*$)' "$ledger")
  [[ -n "$open" ]] || exit 0
  # A gate, or something left running that wakes the session, may end the turn.
  jq -e 'any(.[]; .type == "tool_use" and (.name == "AskUserQuestion" or .name == "Monitor" or .name == "Agent" or .input.run_in_background == true))' <<<"$turn" >/dev/null && exit 0
  first=$(sed -n '/[^[:space:]]/{p;q}' <<<"$said")
  [[ "$first" == '🚪 Waiting on you:'* ]] && exit 0
  send "The over-to-you read-back is not done: these ledger lines are still open, or closed as no bug with no reason. Close each as fixed (with its commit), handed on (with its ticket or subagent), or no bug (with the reason), then report.
$open"
fi
grep -q '^🏁 Done:' <<<"$said" || exit 0
grep -lE '^[0-9]+\. \[[ ~-]\]' "$dir"/over-to-you-*.md >/dev/null 2>&1 || exit 0
send "An over-to-you page of this session was closed with items not marked [x], and no ledger exists. Write over-to-you-ledger.md in the session scratch folder, one line per find as F<n> | open | <the find>, close each line, then report."
