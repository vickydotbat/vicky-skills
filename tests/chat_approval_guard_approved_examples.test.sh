#!/usr/bin/env bash
# approved-spec: the examples approved for "approval is a page tick, never a
# chat reply". Each check is named after its example.
set -u
hook="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/chat-approval-guard.sh"
fx=$(mktemp -d); trap 'rm -rf "$fx"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
user() { jq -nc --arg t "$1" '{type:"user",message:{content:$t}}'; }
text() { jq -nc --arg t "$1" '{type:"assistant",message:{content:[{type:"text",text:$t}]}}'; }
# Stops the agent: $1 is the setting (default on), $2 whether the stop hook is already active.
stop() { jq -nc --arg t "$fx/t.jsonl" --argjson a "${2:-false}" '{stop_hook_active:$a,transcript_path:$t}' |
  CLAUDE_PLUGIN_OPTION_GUARD_CHAT_APPROVAL="${1:-}" bash "$hook" 2>/dev/null; }
sent_back() { [ "$(stop "${1:-}" | jq -r '.decision // empty' 2>/dev/null)" = block ]; }
passes() { local out; out=$(stop "${1:-}"); [ $? = 0 ] && [ -z "$out" ]; }

# Given an agent's last reply asks the user to approve, confirm or give an "ok" for examples, a spec or text for an audience, and holds no page link
# When the agent stops
# Then the reply is sent back with a line telling it to put the text on a page for the user's tick
{ user "go"; text "The four examples are ready. Please approve them: reply ok, or edit any line you want changed."; } > "$fx/t.jsonl"
check "A1 with a reply that asks the user to approve examples and holds no page link, the stop is sent back with a line telling it to put the text on a page for the user's tick" \
  'sent_back && stop | jq -r .reason | grep -qi "page" && stop | jq -r .reason | grep -qi "tick"'

# Given an agent's last reply asks for a tick and holds the link to an open page
# When the agent stops
# Then it stops
{ user "go"; text "Please approve the four examples: tick each one at http://127.0.0.1:40415/ and press Done."; } > "$fx/t.jsonl"
check "A2 with a reply that asks for a tick and holds the link to an open page, the agent stops" 'passes'

# Given an agent's last reply offers the user a pick between two options for a decision, and names no examples, spec or audience text
# When the agent stops
# Then it stops
{ user "go"; text "Two ways to name the branch: the short one or the long one. Which do you want?"; } > "$fx/t.jsonl"
check "A3 with a reply that offers a pick between two options and names no examples, spec or audience text, the agent stops" 'passes'

# Given the chat approval guard setting turned off
# When an agent's reply asks for approval in chat
# Then it stops
{ user "go"; text "The four examples are ready. Please approve them: reply ok, or edit any line you want changed."; } > "$fx/t.jsonl"
check "A4 with the chat approval guard setting turned off, a reply that asks for approval in chat stops" 'passes false'
exit $fail
