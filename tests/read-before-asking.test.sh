#!/usr/bin/env bash
# read-before-asking's decisions: an options gate with no ticket read is sent
# back, and every other case goes through.
set -u
hook="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/read-before-asking.sh"
fx=$(mktemp -d); trap 'rm -rf "$fx"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
user() { jq -nc --arg t "$1" '{type:"user",message:{content:$t}}'; }
text() { jq -nc --arg t "$1" '{type:"assistant",message:{content:[{type:"text",text:$t}]}}'; }
sendmsg() { jq -nc --arg t "$1" '{type:"assistant",message:{content:[{type:"tool_use",name:"SendUserMessage",input:{message:$t}}]}}'; }
bash_() { jq -nc --arg c "$1" '{type:"assistant",message:{content:[{type:"tool_use",name:"Bash",input:{command:$c}}]}}'; }
run() { jq -nc --arg t "$fx/t.jsonl" --argjson a "${1:-false}" '{stop_hook_active:$a,transcript_path:$t}' | bash "$hook" 2>/dev/null; }
sent_back() { [ "$(run | jq -r '.decision // empty' 2>/dev/null)" = block ]; }
passes() { local out; out=$(run "${1:-false}"); [ $? = 0 ] && [ -z "$out" ]; }
ask="🚪 Waiting on you: O1 or O2 for chat. One word is enough."

{ user "go"; text "$ask"; } > "$fx/t.jsonl"
check "an options gate with no ticket read is sent back" 'sent_back'
{ user "go"; sendmsg "$ask"; } > "$fx/t.jsonl"
check "an options gate sent with SendUserMessage is sent back" 'sent_back'
{ user "go"; bash_ "git status"; text "$ask"; } > "$fx/t.jsonl"
check "another command is no ticket read" 'sent_back'

for c in "bash scripts/read-item.sh GAME-716" "gh issue view 12 --comments" "gh pr view 201 --comments" "tea issues 33 --comments </dev/null" "bin/plane get GAME-716"; do
  { user "go"; bash_ "$c"; text "$ask"; } > "$fx/t.jsonl"
  check "a ticket read lets the gate through: $c" 'passes'
done

{ user "go"; text "🚪 Waiting on you: log in and press Save."; } > "$fx/t.jsonl"
check "a gate with no options goes through" 'passes'
{ user "go"; text "O1 is built. Next I push."; } > "$fx/t.jsonl"
check "options with no gate go through" 'passes'
{ user "go"; text 'The gate reads `🚪 Waiting on you: O1`.'; } > "$fx/t.jsonl"
check "a gate in quoted code goes through" 'passes'
{ user "go"; text "$ask"; } > "$fx/t.jsonl"
check "the second stop of a turn goes through" 'passes true'
check "the setting off lets it through" 'CLAUDE_PLUGIN_OPTION_GUARD_READ_BEFORE_ASKING=false passes'
check "the setting at 0 lets it through" 'CLAUDE_PLUGIN_OPTION_GUARD_READ_BEFORE_ASKING=0 passes'
check "a missing transcript goes through" 'out=$(jq -nc "{stop_hook_active:false,transcript_path:\"$fx/none\"}" | bash "$hook"); [ -z "$out" ]'
check "bad input goes through" 'out=$(echo "not json" | bash "$hook" 2>/dev/null); [ -z "$out" ]'
exit $fail
