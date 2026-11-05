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
skill() { jq -nc --arg s "$1" '{type:"assistant",message:{content:[{type:"tool_use",name:"Skill",input:{skill:$s}}]}}'; }
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
{ user "council it"; skill council-of-elrond; sent "Gandalf: my pick is O1. O1 or O2?"; } > "$fx/t.jsonl"
check "a seat's pick in a sitting council passes" 'out=$(stop); [ $? = 0 ] && [ -z "$out" ]'
{ user "council it"; skill council-of-elrond; sent "**Frodo:** I will take it."; user "go"; sent "🚪 Waiting on you: O1 (my pick) or O2? Answer in chat."; } > "$fx/t.jsonl"
check "a pick after the council concluded is still sent back" 'blocked'
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
{ user "go"; jq -nc '{type:"user",isMeta:true,message:{content:[{type:"text",text:"Base directory for this skill"}]}}'; sent "🚪 Waiting on you: O1 (my pick) or O2?"; } > "$fx/t.jsonl"
check "injected skill text is no user message, so the reply before it still counts" 'blocked'
{ user "go"; sent "🚪 Waiting on you: run probe 1.
1. Start the client.
2. Run dm_runscript rgbprobe."; } > "$fx/t.jsonl"
check "numbered steps for the user in a gate, with no page, go to over-to-you" 'stop | jq -r .reason | grep -q over-to-you'
{ user "go"; sent "🚪 Waiting on you: run probe 1, my pick is now. OK?
1. Start the client.
2. Run the probe."; } > "$fx/t.jsonl"
check "steps with a pick are sent back once, with exit 0" 'out=$(stop); [ $? = 0 ] && [ "$(jq -s length <<<"$out")" = 1 ] && grep -q over-to-you <<<"$out"'
{ user "go"; sent "🚪 Waiting on you: the checklist at http://127.0.0.1:4000/
1. Start the client.
2. Run the probe."; } > "$fx/t.jsonl"
check "numbered steps beside a page link go through" 'passes'
{ user "go"; sent "🚪 Waiting on you: the merge of #12.
1. CI is green."; } > "$fx/t.jsonl"
check "one numbered line in a gate goes through" 'passes'
check "the setting off lets it through" '{ user "go"; text "My pick is A. Which?"; } > "$fx/t.jsonl"; CLAUDE_PLUGIN_OPTION_GUARD_TAKE_PICK=false passes'
check "a missing transcript goes through" 'out=$(jq -nc "{transcript_path:\"$fx/none\"}" | bash "$hook"); [ $? = 0 ] && [ -z "$out" ]'
check "bad input goes through" 'out=$(echo "not json" | bash "$hook"); [ $? = 0 ] && [ -z "$out" ]'
{ user "sup"; skill vicky-skills:sup; sent "Next: the handoff says to warp GAME-1. Say **go** and I start N1."; } > "$fx/t.jsonl"
check "a sup that found a handoff and asks for go is sent back" 'blocked && { stop >/dev/null; [ $? = 0 ]; }'
{ user "sup"; skill sup; sent "Next: say go and I start N1."; } > "$fx/t.jsonl"
check "a sup with no handoff may ask for go" 'passes'
{ user "status"; sent "The handoff says to warp GAME-1. Say go and I start."; } > "$fx/t.jsonl"
check "a handoff go with no sup this turn passes" 'passes'
{ user "sup"; skill sup; sent "The handoff says warp GAME-1. My pick is warp. Say go?"; } > "$fx/t.jsonl"
check "a handoff go with a pick and a question is sent back once, for the handoff" '[ "$(stop | jq -s "length")" = 1 ] && stop | grep -q "sup step 4"'
# Given a reply that takes one pick with "Going with" and asks about another below it
# When the agent stops
# Then the second pick is sent back, since a "Going with" covers only the text above it
{ user "go"; sent "Weapon sets are live. Going with a Holster square on each set.
Picker question: where do the icon rows open? Answer with a letter in chat:
- A (my pick): a pop-up at the cursor.
- B: an in-hub panel."; } > "$fx/t.jsonl"
check "a pick asked below an unrelated Going with is sent back" 'blocked'
{ user "go"; sent "Picker question: where do the icon rows open? A is my pick.
Going with A."; } > "$fx/t.jsonl"
check "a Going with below the question takes it" 'passes'
{ user "go"; sent "Going with A.
The build is green."; } > "$fx/t.jsonl"
check "a Going with with nothing asked below it goes through" 'passes'
{ user "go"; sent "Going with A."; } > "$fx/t.jsonl"
check "a Going with on the last line goes through" 'passes'
{ user "go"; sent "A is my pick, or B. Answer with a letter in chat."; } > "$fx/t.jsonl"
check "an Answer with ask, with no question mark, is sent back" 'blocked'
{ user "go"; sent "A is my pick, or B. Reply with a letter."; } > "$fx/t.jsonl"
check "a Reply with ask, with no question mark, is sent back" 'blocked'
{ user "go"; sent "🚪 Still waiting on your picker letter: A (my pick) or B. Answer with a letter in chat."; } > "$fx/t.jsonl"
check "a still-waiting gate that asks its pick in chat is sent back" 'blocked'
{ user "go"; sent "🚪 Still waiting on you: the merge of #12. My pick is squash."; } > "$fx/t.jsonl"
check "a still-waiting gate with no question goes through" 'passes'
{ user "go"; sent "Going with a Holster square.
Which letter? B is my pick.
Going with B."; } > "$fx/t.jsonl"
check "only the text below the last Going with is weighed" 'passes'
{ user "go"; sent "🚪 Still waiting on you: run probe 1.
1. Start the client.
2. Run the probe."; } > "$fx/t.jsonl"
check "a still-waiting gate with numbered steps goes to over-to-you" 'stop | jq -r .reason | grep -q over-to-you'
{ user "go"; sent "🚪 Waiting on you: A (my pick) or B. Answer with a letter."; } > "$fx/t.jsonl"
check "a gated pick that says Answer with, with no question mark, is sent back" 'blocked'
# Given a gate that links its page and also leaves a yes or no question in chat
# When the agent stops
# Then the stop is sent back to take the cheap one, or put it on the page
{ user "go"; sent "🚪 Waiting on you: the slot bar page, http://127.0.0.1:44623/ (Done sends it back)

Also open: ex 19 to GAME-2562, yes or no."; } > "$fx/t.jsonl"
check "a page gate with a yes or no question beside it is sent back" 'blocked'
check "that steer exits 0 with one answer" 'out=$(stop); [ $? = 0 ] && [ "$(jq -s length <<<"$out")" = 1 ]'
check "that steer says to take it or put it on the page" 'stop | jq -r .reason | grep -q "Going with" && stop | jq -r .reason | grep -q "page"'
{ user "go"; sent "🚪 Waiting on you: may I post the 6 examples, http://127.0.0.1:44623/? A yes is enough."; } > "$fx/t.jsonl"
check "A yes is enough beside a page link is sent back" 'blocked'
{ user "go"; sent "🚪 Waiting on you: the slot bar page, http://127.0.0.1:44623/ (Done sends it back)"; } > "$fx/t.jsonl"
check "a page gate with no chat question goes through" 'passes'
{ user "go"; sent "Going with filing ex 19 to GAME-2562.
🚪 Waiting on you: the slot bar page, http://127.0.0.1:44623/"; } > "$fx/t.jsonl"
check "a taken pick above a clean page gate goes through" 'passes'
exit $fail
