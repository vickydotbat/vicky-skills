#!/usr/bin/env bash
# approved-spec: the examples approved on 2026-11-06 for the hook audit, E5.
# A wait run under the Monitor tool or in the background never holds the
# session, so poll-pace lets it through.
set -u
guard="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/poll-pace.sh"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
loop='for i in $(seq 1 120); do tea actions runs view 5; sleep 30; done'

# Given a capped loop run under the Monitor tool
# When poll-pace sees it
# Then it goes through
check "E5 a capped loop under Monitor goes through" \
  'jq -nc --arg c "$loop" "{tool_name:\"Monitor\",tool_input:{command:\$c,timeout_ms:1800000}}" | CLAUDE_PLUGIN_OPTION_GUARD_POLL_PACE=true bash "$guard" 2>/dev/null'

# Given a capped loop run in the background with Bash
# When poll-pace sees it
# Then it goes through
check "E5 a capped background loop goes through" \
  'jq -nc --arg c "$loop" "{tool_name:\"Bash\",tool_input:{command:\$c,run_in_background:true}}" | CLAUDE_PLUGIN_OPTION_GUARD_POLL_PACE=true bash "$guard" 2>/dev/null'
exit $fail
