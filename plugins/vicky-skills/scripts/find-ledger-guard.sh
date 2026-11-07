#!/usr/bin/env bash
# Stop hook (guard_find_ledger, on by default): an over-to-you read-back is
# done only when every find in its ledger is closed. The ledger is
# over-to-you-ledger.md in the session scratch folder, one line per find as
# `F<n> | open|fixed|handed on | <ref>`. A reply whose first line is
# "🏁 Done:" while a line is still open is sent back once, naming the open
# lines. No ledger, no done line, a second stop and a missing tool pass.
set -u
case "${CLAUDE_PLUGIN_OPTION_GUARD_FIND_LEDGER:-}" in false|0) exit 0 ;; esac
command -v jq >/dev/null || exit 0 # mutant-ok delete: without the tool every later read comes back empty, and the hook exits 0 the same way
# shellcheck source=stop-reply.sh
. "$(dirname "$0")/stop-reply.sh"
sid=$(jq -r '.session_id // ""' <<<"$payload" 2>/dev/null)
ledger="/tmp/$sid/over-to-you-ledger.md"
grep -q '^🏁 Done:' <<<"$said" || exit 0
open=$(grep -E '^F[0-9]+[[:space:]]*\|[[:space:]]*open([[:space:]]|\|)' "$ledger" 2>/dev/null | cut -c1-120)
[[ -n "$open" ]] || exit 0
jq -n --arg o "$open" '{decision:"block", reason:("The over-to-you read-back is not done: these ledger lines are still open. Close each as fixed (with its commit) or handed on (with its ticket or subagent), then report.\n" + $o)}'
