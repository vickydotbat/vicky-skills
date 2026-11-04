#!/usr/bin/env bash
# The take-the-pick hook: a question asked with a pick and no gate is sent
# back once; a taken pick, a gate, a pick with no question, and bad input go
# through.
set -u
hook="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/take-pick.sh"
fx=$(mktemp -d); trap 'rm -rf "$fx"' EXIT
export CLAUDE_PLUGIN_OPTION_GUARD_TAKE_PICK=true
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
user() { jq -nc --arg t "$1" '{type:"user",message:{content:$t}}'; }
text() { jq -nc --arg t "$1" '{type:"assistant",message:{content:[{type:"text",text:$t}]}}'; }
sent() { jq -nc --arg t "$1" '{type:"assistant",message:{content:[{type:"tool_use",name:"SendUserMessage",input:{message:$t}}]}}'; }
stop() { jq -nc --arg t "$fx/t.jsonl" --argjson a "${1:-false}" '{stop_hook_active:$a,transcript_path:$t}' | bash "$hook"; }
passes() { local out; out=$(stop "$@"); [ $? = 0 ] && [ -z "$out" ]; }
blocked() { stop | jq -e '.decision == "block"' >/dev/null 2>&1; }
# Given a reply that gives a pick and asks a question, with no gate
# When the agent stops
# Then the stop is blocked once with a steer to take the pick or gate it
{ user "go"; sent "My pick is O1, because the skills drive now. Is that a pivot? Answer yes or no in chat."; } > "$fx/t.jsonl"
check "a pick with an ungated question is sent back" 'blocked'
check "a sent-back stop exits 0" 'stop >/dev/null; [ $? = 0 ]'
check "the steer quotes the question" 'stop | jq -r .reason | grep -q "Is that a pivot?"'
check "the steer names both ways out" 'stop | jq -r .reason | grep -q "Going with <pick>" && stop | jq -r .reason | grep -q "Waiting on you"'
check "a second stop in the same turn goes through" 'passes true'
for p in "I recommend A. Which one?" "Pick: B. Want it?"; do
  { user "go"; text "$p"; } > "$fx/t.jsonl"
  check "each pick marker counts: $p" 'blocked'
done
# Given a reply that takes its pick, or gates the question
# When the agent stops
# Then it goes through
{ user "go"; sent "My pick is O1. Going with O1. Say stop if not?"; } > "$fx/t.jsonl"
check "a taken pick goes through" 'passes'
{ user "go"; sent "🚪 Waiting on you: the merge. My pick is squash. OK?"; } > "$fx/t.jsonl"
check "a gated pick asking OK? in chat is sent back" 'blocked'
{ user "go"; sent "🚪 Waiting on you: O1 (my pick) or O2? Answer in chat."; } > "$fx/t.jsonl"
check "a gated pick asked in chat is sent back with one answer and exit 0" 'out=$(stop); [ $? = 0 ] && [ "$(jq -s length <<<"$out")" = 1 ]'
{ user "go"; sent "🚪 Waiting on you: O1 (my pick): add a 15s timeout. O2: leave it."; } > "$fx/t.jsonl"
check "a gated pick between options, with no page, is sent back" 'stop | jq -e '"'"'.decision == "block"'"'"' >/dev/null'
{ user "go"; sent "🚪 Waiting on you: can I run the compiler? My pick is yes."; } > "$fx/t.jsonl"
check "a gated pick asked as a question, with no page, is sent back" 'stop | jq -e '"'"'.decision == "block"'"'"' >/dev/null'
{ user "go"; sent "🚪 Waiting on you: the merge of #12. My pick is squash. Watching it."; } > "$fx/t.jsonl"
check "a gated pick with no question and no options goes through" '[ -z "$(stop)" ]'
{ user "go"; text "My pick is O1, and I built it."; } > "$fx/t.jsonl"
check "a pick with no question goes through" 'passes'
{ user "go"; text "Which file should I read?"; } > "$fx/t.jsonl"
check "a question with no pick goes through" 'passes'
{ user "go"; text 'The hook reads `my pick` and `Pick:` as picks. Should it read `I recommend` too?'; } > "$fx/t.jsonl"
check "a pick quoted in backticks is no pick" 'passes'
{ user "go"; text 'My pick is to drop `sleep`. Which one?'; } > "$fx/t.jsonl"
check "a pick outside backticks still counts" '! passes'
{ user "go"; text "My pick is A. Which one?"; user "A"; text "Done."; } > "$fx/t.jsonl"
check "a question before the user's last message is not read again" 'passes'
check "the setting off lets it through" '{ user "go"; text "My pick is A. Which?"; } > "$fx/t.jsonl"; CLAUDE_PLUGIN_OPTION_GUARD_TAKE_PICK=false passes'
check "a missing transcript goes through" 'out=$(jq -nc "{transcript_path:\"$fx/none\"}" | bash "$hook"); [ $? = 0 ] && [ -z "$out" ]'
check "bad input goes through" 'out=$(echo "not json" | bash "$hook"); [ $? = 0 ] && [ -z "$out" ]'
exit $fail
