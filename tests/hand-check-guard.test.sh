#!/usr/bin/env bash
# hand-check-guard's decisions beyond its approved examples: each phrase that
# hands the user a check, each place word, the session that already ran
# over-to-you, quoted code, SendUserMessage and the second stop of a turn.
set -u
hook="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/hand-check-guard.sh"
fx=$(mktemp -d); trap 'rm -rf "$fx"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
user() { jq -nc --arg t "$1" '{type:"user",message:{content:$t}}'; }
text() { jq -nc --arg t "$1" '{type:"assistant",message:{content:[{type:"text",text:$t}]}}'; }
sendmsg() { jq -nc --arg t "$1" '{type:"assistant",message:{content:[{type:"tool_use",name:"SendUserMessage",input:{message:$t}}]}}'; }
skill() { jq -nc --arg s "$1" '{type:"assistant",message:{content:[{type:"tool_use",name:"Skill",input:{skill:$s}}]}}'; }
stop() { jq -nc --arg t "$fx/t.jsonl" --argjson a "${1:-false}" '{stop_hook_active:$a,transcript_path:$t}' | bash "$hook" 2>/dev/null; }
sent_back() { [ "$(stop "${1:-false}" | jq -r '.decision // empty' 2>/dev/null)" = block ]; }
passes() { local out; out=$(jq -nc --arg t "$fx/t.jsonl" --argjson a "${1:-false}" '{stop_hook_active:$a,transcript_path:$t}' | bash "$hook" 2>/dev/null); [ $? = 0 ] && [ -z "$out" ]; }
says() { { user "go"; text "$1"; } > "$fx/t.jsonl"; }

for reply in \
  "You can try it in game now." \
  "You could test it in the client." \
  "Please check it in your browser." \
  "Now play it in the game and tell me." \
  "Try it out in the client." \
  "Test this yourself in the browser."; do
  says "$reply"
  check "a reply that hands the user a check is sent back: $reply" 'sent_back'
done

for reply in \
  "You can try the new flag, it is in the README." \
  "Please check the logs for the error." \
  "I tried it in game with a bot and it passed." \
  "The client tests passed." \
  "You can check the diff on the pull request."; do
  says "$reply"
  check "a reply that hands no live check goes through: $reply" 'passes'
done

says 'Run `try it in game` in the console.'
check "quoted code is no hand-off" 'passes'

{ user "go"; sendmsg "When it is green you can try it in game: 1. Drop a coat."; } > "$fx/t.jsonl"
check "a hand-off sent with SendUserMessage is sent back" 'sent_back'

{ user "go"; skill "vicky-skills:over-to-you"; text "You can try it in game: the steps are on the page."; } > "$fx/t.jsonl"
check "a session that already ran over-to-you goes through" 'passes'

{ user "go"; skill "vicky-skills:do"; text "You can try it in game now."; } > "$fx/t.jsonl"
check "another skill is no over-to-you" 'sent_back'

says "You can try it in game now."
check "the second stop of a turn goes through" 'passes true'

check "a missing transcript goes through" '[ -z "$(jq -nc "{stop_hook_active:false,transcript_path:\"$fx/none.jsonl\"}" | bash "$hook" 2>/dev/null)" ]'
check "the setting at 0 turns the guard off" '[ -z "$(jq -nc --arg t "$fx/t.jsonl" "{stop_hook_active:false,transcript_path:\$t}" | CLAUDE_PLUGIN_OPTION_GUARD_HAND_CHECK=0 bash "$hook" 2>/dev/null)" ]'
exit $fail
