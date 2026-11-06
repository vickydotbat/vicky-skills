#!/usr/bin/env bash
# The chat approval guard sends back a reply that asks for approval of
# examples, a spec or text in chat with no page link, and lets a page link, a
# reply with no approval ask or no such subject, quoted code, a second stop,
# a missing transcript and the setting off through. It reads a reply sent
# through SendUserMessage too.
set -u
hook="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/chat-approval-guard.sh"
fx=$(mktemp -d); trap 'rm -rf "$fx"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
user() { jq -nc --arg t "$1" '{type:"user",message:{content:$t}}'; }
text() { jq -nc --arg t "$1" '{type:"assistant",message:{content:[{type:"text",text:$t}]}}'; }
sent() { jq -nc --arg t "$1" '{type:"assistant",message:{content:[{type:"tool_use",name:"SendUserMessage",input:{message:$t}}]}}'; }
stop() { jq -nc --arg t "${TRANSCRIPT:-$fx/t.jsonl}" --argjson a "${2:-false}" '{stop_hook_active:$a,transcript_path:$t}' |
  env -u CLAUDE_PLUGIN_OPTION_GUARD_CHAT_APPROVAL ${1:+CLAUDE_PLUGIN_OPTION_GUARD_CHAT_APPROVAL=$1} bash "$hook" 2>/dev/null; }
blocked() { [ "$(stop "${1:-}" "${2:-false}" | jq -r '.decision // empty' 2>/dev/null)" = block ]; }
passes() { local out; out=$(stop "${1:-}" "${2:-false}"); [ $? = 0 ] && [ -z "$out" ]; }
reply() { { user "go"; text "$1"; } > "$fx/t.jsonl"; }

reply "Please approve the examples."
check "the setting unset stays on" 'blocked'
check "the setting true is on" 'blocked true'
check "the setting 1 is on" 'blocked 1'
check "the setting false is off" 'passes false'
check "the setting 0 is off" 'passes 0'
check "a second stop in the same turn goes through" 'passes "" true'
check "a sent-back stop exits 0" 'stop >/dev/null; [ $? = 0 ]'
check "the steer names the page and the red-pen skill" 'stop | jq -r .reason | grep -q "red-pen" && stop | jq -r .reason | grep -qi "page"'
check "a missing transcript goes through" 'TRANSCRIPT="$fx/none.jsonl" passes'
for ask in "Please approve the examples." "Can you confirm the examples?" "I need your ok on the examples." "I need your approval on the examples." "Reply ok to take the examples." "Say yes to take the examples." "Tick the examples."; do
  reply "$ask"; check "each approval ask counts: $ask" 'blocked'
done
for subject in examples example spec wording draft text row copy notes; do
  reply "Please approve the $subject."; check "each subject counts: $subject" 'blocked'
done
reply "Please approve the plan."
check "an approval ask with no examples, spec or text goes through" 'passes'
reply "Here are the examples I wrote."
check "a subject with no approval ask goes through" 'passes'
reply "Please approve the examples at http://127.0.0.1:40415/ and press Done."
check "a page link goes through" 'passes'
reply "Please approve the examples at https://example.invalid/page and press Done."
check "an https link goes through" 'passes'
reply "Run \`approve the examples\` to start it."
check "quoted code is no ask" 'passes'
{ user "go"; sent "Please approve the examples: reply ok."; } > "$fx/t.jsonl"
check "a reply sent through SendUserMessage is read too" 'blocked'
{ user "go"; text "Please approve the examples."; user "again"; text "Done, nothing to ask."; } > "$fx/t.jsonl"
check "only the reply since the user's last message counts" 'passes'
exit $fail
