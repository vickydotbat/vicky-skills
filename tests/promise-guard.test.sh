#!/usr/bin/env bash
# promise-guard sends a reply that promises to do better back through
# engrave, unless the turn ran engrave or printed its line; every other reply
# goes through.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
hook="$root/plugins/vicky-skills/scripts/promise-guard.sh"
fx=$(mktemp -d); trap 'rm -rf "$fx"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
user() { jq -nc --arg t "$1" '{type:"user",message:{content:$t}}'; }
text() { jq -nc --arg t "$1" '{type:"assistant",message:{content:[{type:"text",text:$t}]}}'; }
sendmsg() { jq -nc --arg t "$1" '{type:"assistant",message:{content:[{type:"tool_use",name:"SendUserMessage",input:{message:$t}}]}}'; }
skill() { jq -nc --arg s "$1" '{type:"assistant",message:{content:[{type:"tool_use",name:"Skill",input:{skill:$s}}]}}'; }
run() { jq -nc --arg t "$fx/t.jsonl" --argjson a "${1:-false}" '{stop_hook_active:$a,transcript_path:$t}' | CLAUDE_PLUGIN_OPTION_GUARD_PROMISE="${opt-}" bash "$hook" 2>/dev/null; }
sent_back() { [ "$(run | jq -r '.decision // empty' 2>/dev/null)" = block ]; }
passes() { local out; out=$(run "${1:-false}"); [ $? = 0 ] && [ -z "$out" ]; }

for p in "That was my mistake. From now on I'll read a script before I run it." \
         "Going forward, I will check the header first." \
         "Next time I'll ask." "In future, I'll read it." \
         "I'll remember to read it." "I won't run a script unread again." \
         "I will never skip that step again." "Lesson learned." ; do
  { user "go"; text "$p"; } > "$fx/t.jsonl"
  check "a promise is sent back: $p" 'sent_back'
done
{ user "go"; sendmsg "From now on I'll read it first."; } > "$fx/t.jsonl"
check "a promise sent with SendUserMessage is sent back" 'sent_back'
{ user "go"; text "From now on I'll read it first."; } > "$fx/t.jsonl"
check "the reason quotes the promise" '[[ "$(run)" == *"From now on I'"'"'ll read it first"* ]]'
check "the reason names engrave" '[[ "$(run)" == *"engrave skill"* ]]'

{ user "go"; skill "vicky-skills:engrave"; text "From now on I'll read it first."; } > "$fx/t.jsonl"
check "an engrave run this turn lets it through" 'passes'
{ user "go"; skill "engrave"; text "Next time I'll ask."; } > "$fx/t.jsonl"
check "an unprefixed engrave run lets it through" 'passes'
{ user "go"; skill "vicky-skills:engrave-not"; text "Next time I'll ask."; } > "$fx/t.jsonl"
check "another skill is no engrave run" 'sent_back'
{ user "go"; text "Next time I'll ask. 📓 Engraved: x → y in z"; } > "$fx/t.jsonl"
check "the engraved line lets it through" 'passes'
{ user "go"; skill "vicky-skills:engrave"; user "and now"; text "Next time I'll ask."; } > "$fx/t.jsonl"
check "an engrave run before the user's last message is old" 'sent_back'
{ user "go"; text 'The hook catches `from now on I will do it` lines.'; } > "$fx/t.jsonl"
check "a promise inside backticks is quoted code" 'passes'
{ user "go"; text "Merged. The next run starts at noon."; } > "$fx/t.jsonl"
check "a reply with no promise goes through" 'passes'
{ user "go"; text "From now on I'll read it first."; } > "$fx/t.jsonl"
check "the second stop of a turn goes through" 'passes true'
check "a missing transcript goes through" 'rm -f "$fx/t.jsonl"; passes'
{ user "go"; text "From now on I'll read it first."; } > "$fx/t.jsonl"
opt=false; check "the setting off lets it through" 'passes'
opt=0; check "the setting 0 lets it through" 'passes'
opt=true; check "the setting on sends it back" 'sent_back'
unset opt
mkdir -p "$fx/nobin"; for t in bash cat sed grep tail head; do ln -s "$(command -v "$t")" "$fx/nobin/$t"; done
check "without jq it goes through" '[ -z "$(jq -nc --arg t "$fx/t.jsonl" "{transcript_path:\$t}" | PATH="$fx/nobin" bash "$hook" 2>&1)" ]'
exit $fail
