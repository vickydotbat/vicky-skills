#!/usr/bin/env bash
# approved-spec: the examples approved on the star "take-pick sends back a
# gated pick asked in chat". Each check is named after its example.
set -u
hook="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/take-pick.sh"
fx=$(mktemp -d); trap 'rm -rf "$fx"' EXIT
export CLAUDE_PLUGIN_OPTION_GUARD_TAKE_PICK=true
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
user() { jq -nc --arg t "$1" '{type:"user",message:{content:$t}}'; }
sent() { jq -nc --arg t "$1" '{type:"assistant",message:{content:[{type:"tool_use",name:"SendUserMessage",input:{message:$t}}]}}'; }
stop() { jq -nc --arg t "$fx/t.jsonl" '{stop_hook_active:false,transcript_path:$t}' | bash "$hook"; }
passes() { local out; out=$(stop); [ $? = 0 ] && [ -z "$out" ]; }

# Given a reply that opens a gate, gives a pick and asks for the answer in chat
# When the agent stops
# Then the stop is sent back once, with a steer to take the pick now or put the question on a page
{ user "go"; sent "🚪 Waiting on you: one more tick. O1 (my pick): open the page. O2: park it. Answer O1 or O2 in chat."; } > "$fx/t.jsonl"
check "a gate with a pick and an answer asked in chat is sent back, steered to take the pick or use a page" \
  'stop | jq -e ".decision == \"block\"" >/dev/null && stop | jq -r .reason | grep -q "Going with" && stop | jq -r .reason | grep -qi "page"'
# Given a gate whose question is on a page, with its link in the reply
# When the agent stops
# Then it goes through
{ user "go"; sent "🚪 Waiting on you: the examples at http://127.0.0.1:4000/ (Done sends them back). My pick is to tick all three."; } > "$fx/t.jsonl"
check "a gate whose question is on a page goes through" 'passes'
# Given a gate on a merge or another person's move, with a pick and no answer asked in chat
# When the agent stops
# Then it goes through
{ user "go"; sent "🚪 Waiting on you: the merge of #12. My pick is squash. I am watching the pull request's state."; } > "$fx/t.jsonl"
check "a gate on a merge, with a pick and no chat answer asked, goes through" 'passes'
exit $fail
