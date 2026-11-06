#!/usr/bin/env bash
# approved-spec: the examples approved for "a comparison, a fault in the current
# build or a retraction is no stale claim". Each check is named after its example.
set -u
hook="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/stale-blame.sh"
fx=$(mktemp -d); trap 'rm -rf "$fx"' EXIT
unset CLAUDE_PLUGIN_OPTION_GUARD_STALE_BLAME
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
user() { jq -nc --arg t "$1" '{type:"user",message:{content:$t}}'; }
text() { jq -nc --arg t "$1" '{type:"assistant",message:{content:[{type:"text",text:$t}]}}'; }
stop() { jq -nc --arg t "$fx/t.jsonl" '{stop_hook_active:false,transcript_path:$t}' | bash "$hook" 2>/dev/null; }
passes() { local out; out=$(stop); [ $? = 0 ] && [ -z "$out" ]; }
blocked() { stop | jq -e '.decision == "block"' >/dev/null 2>&1; }
reply() { { user "go"; text "$1"; } > "$fx/t.jsonl"; }

# Given an agent's last reply says "My F3 camera was aimed 1 m outside where the old rider cap sits, and that roof edge looks the same in your current bare build."
# When the agent stops
# Then it stops
reply "My F3 camera was aimed 1 m outside where the old rider cap sits, and that roof edge looks the same in your current bare build."
check "S1 with a reply that compares the old rider cap with the user's current bare build and says the roof edge looks the same, the agent stops" 'passes'

# Given an agent's last reply says the gap is a fault in the user's current build, and says nothing about the build being old, out of date or needing an update
# When the agent stops
# Then it stops
reply "The gap is a fault in your current build: the cap ends 4 cm short of the post."
check "S2 with a reply that names a fault in the user's current build and says nothing about it being old, out of date or needing an update, the agent stops" 'passes'

# Given an agent's last reply says "I told you the fifth session grepped your old branch checkout, and that was wrong."
# When the agent stops
# Then it stops
reply "I told you the fifth session grepped your old branch checkout, and that was wrong."
check "S3 with a reply that withdraws an earlier claim about the user's old branch checkout, the agent stops" 'passes'

# Given an agent's last reply says the user's build is out of date, with no hash or logged version
# When the agent stops
# Then the reply is sent back with a line telling it to keep tracing the code
reply "The cap shows the old shape because your build is out of date."
check "S4 with a reply that says the user's build is out of date and quotes no hash or version, the stop is sent back with a line telling it to keep tracing the code" \
  'blocked && stop | jq -r .reason | grep -qi "tracing"'

# Given an agent's last reply says the old and current builds look the same, and in the next sentence says the user's client is stale, with no hash or logged version
# When the agent stops
# Then the reply is sent back
reply "The old and current builds look the same. Your client is stale."
check "S5 with a reply that says the old and current builds look the same and, in the next sentence, that the user's client is stale, the stop is sent back" 'blocked'
exit $fail
