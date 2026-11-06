#!/usr/bin/env bash
# approved-spec: the examples approved on 2026-11-06 for "live checks go to the
# user through over-to-you, never as steps in chat". Each check is named after
# its example.
set -u
hook="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/hand-check-guard.sh"
fx=$(mktemp -d); trap 'rm -rf "$fx"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
user() { jq -nc --arg t "$1" '{type:"user",message:{content:$t}}'; }
text() { jq -nc --arg t "$1" '{type:"assistant",message:{content:[{type:"text",text:$t}]}}'; }
# Stops the agent: $1 is the setting (default on), $2 whether the stop hook is already active.
stop() { jq -nc --arg t "$fx/t.jsonl" --argjson a "${2:-false}" '{stop_hook_active:$a,transcript_path:$t}' |
  CLAUDE_PLUGIN_OPTION_GUARD_HAND_CHECK="${1:-}" bash "$hook" 2>/dev/null; }
sent_back() { [ "$(stop "${1:-}" | jq -r '.decision // empty' 2>/dev/null)" = block ]; }
passes() { local out; out=$(stop "${1:-}"); [ $? = 0 ] && [ -z "$out" ]; }

# Given a session where over-to-you has not started
# When the agent's last reply tells the user to try, test or check something themselves in the game, the client or the browser, as steps
# Then the agent is sent back once, told to hand the checks over with over-to-you
{ user "go"; text "The PR is open. When it's green you can try it in game: 1. Drop a coat on the Armor slot. 2. Check it shows."; } > "$fx/t.jsonl"
check "H1 with a reply that hands the user steps to try in the game and no over-to-you started, the stop is sent back with a line naming over-to-you" \
  'sent_back && stop | jq -r .reason | grep -q "over-to-you"'

# Given the same reply, with a link to a page on this machine
# When the agent stops
# Then it stops, with nothing sent back
{ user "go"; text "You can try it in game, the steps are on the page: http://127.0.0.1:40415/ . Press Done when you have."; } > "$fx/t.jsonl"
check "H2 with the same reply and a link to a page on this machine, the agent stops" 'passes'

# Given a reply that says its tests passed and CI is running
# When the agent stops
# Then it stops, with nothing sent back
{ user "go"; text "All 136 tests passed, and CI is running. I'm watching it."; } > "$fx/t.jsonl"
check "H3 with a reply that reports tests passed and CI running, the agent stops" 'passes'

# Given the guard_hand_check setting is off
# When the agent's last reply hands the user steps to try
# Then it stops
{ user "go"; text "The PR is open. When it's green you can try it in game: 1. Drop a coat on the Armor slot. 2. Check it shows."; } > "$fx/t.jsonl"
check "H4 with the hand check guard setting turned off, a reply that hands the user steps to try stops" 'passes false'
exit $fail
