#!/usr/bin/env bash
# Stop hook (guard_find_ledger, on by default): an over-to-you read-back is
# done only when every find in its session ledger is closed, so no find is dropped.
set -u
case "${CLAUDE_PLUGIN_OPTION_GUARD_FIND_LEDGER:-}" in false|0) exit 0 ;; esac
command -v jq >/dev/null || exit 0 # mutant-ok delete: without the tool every later read comes back empty, and the hook exits 0 the same way
# shellcheck source=stop-reply.sh
. "$(dirname "$0")/stop-reply.sh"
sid=$(jq -r '.session_id // ""' <<<"$payload" 2>/dev/null)
[[ -n "$sid" ]] || exit 0
dir="/tmp/$sid"
ledger="$dir/over-to-you-ledger.md"
send() { jq -n --arg r "$1" '{decision:"block", reason:$r}'; exit 0; }
if [[ -f "$ledger" ]]; then
  open=$(grep -E '^F[0-9]+[[:space:]]*\|[[:space:]]*(open[[:space:]]*(\||$)|no bug[[:space:]]*\|[[:space:]]*$)' "$ledger")
  [[ -n "$open" ]] || exit 0
  # A gate, or something left running that wakes the session, may end the turn.
  jq -e 'any(.[]; .type == "tool_use" and (.name == "AskUserQuestion" or .name == "Monitor" or .name == "Agent" or .input.run_in_background == true))' <<<"$turn" >/dev/null && exit 0
  [[ "$(grep -m1 . <<<"$said")" == '🚪 Waiting on you:'* ]] && exit 0
  send "The over-to-you read-back is not done: these ledger lines are still open, or closed as no bug with no reason. Close each as fixed (with its commit), handed on (with its ticket or subagent), or no bug (with the reason), then report.
$open"
fi
grep -q '^🏁 Done:' <<<"$said" || exit 0
grep -qE '^[0-9]+\. \[[ ~-]\]' "$dir"/over-to-you-*.md 2>/dev/null || exit 0
send "An over-to-you page of this session was closed with items not marked [x], and no ledger exists. Write over-to-you-ledger.md in the session scratch folder, one line per find as F<n> | open | <the find>, close each line, then report."
