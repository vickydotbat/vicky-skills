#!/usr/bin/env bash
# cerebro-ask-guard sends back a Cerebro ask whose reason is a new pull
# request; every other reply goes through.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
hook="$root/plugins/vicky-skills/scripts/cerebro-ask-guard.sh"
fx=$(mktemp -d); trap 'rm -rf "$fx"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
user() { jq -nc --arg t "$1" '{type:"user",message:{content:$t}}'; }
text() { jq -nc --arg t "$1" '{type:"assistant",message:{content:[{type:"text",text:$t}]}}'; }
sendmsg() { jq -nc --arg t "$1" '{type:"assistant",message:{content:[{type:"tool_use",name:"SendUserMessage",input:{message:$t}}]}}'; }
run() { jq -nc --arg t "$fx/t.jsonl" '{stop_hook_active:false,transcript_path:$t}' | CLAUDE_PLUGIN_OPTION_GUARD_CEREBRO_ASK="${opt-}" bash "$hook" 2>/dev/null; }
sent_back() { [ "$(run | jq -r '.decision // empty' 2>/dev/null)" = block ]; }
passes() { local out; out=$(run); [ $? = 0 ] && [ -z "$out" ]; }
# The snag's own reply, cut to its Cerebro block.
snag=$'Merged.\n\n🧠 **Cerebro**\n- C2: Make the installs skip apt-get update. It\'s a new pull request, about half an hour with CI.\n\n🚪 Waiting on you: reply **yes** to C2 or **leave it**.'
{ user "make it so"; text "$snag"; } > "$fx/t.jsonl"
check "the snag's ask is sent back" 'sent_back'
check "the reason quotes the ask" '[[ "$(run)" == *"new pull request, about half an hour"* ]]'
{ user "go"; text $'🧠 **Cerebro**\n- C1: Split the job. Waits on you: a new PR changes which checks show.'; } > "$fx/t.jsonl"
check "a new PR as the reason is sent back" 'sent_back'
{ user "go"; sendmsg "$snag"; } > "$fx/t.jsonl"
check "an ask sent with SendUserMessage is sent back" 'sent_back'
{ user "go"; text $'🧠 **Cerebro**\n- C1: Delete the old branch. Waits on you: a deletion. Want it?'; } > "$fx/t.jsonl"
check "an ask for a deletion goes through" 'passes'
{ user "go"; text $'🧠 **Cerebro**\n- C1: Split the job in a new pull request. Done: #285 is green.'; } > "$fx/t.jsonl"
check "a built proposal in a new pull request goes through" 'passes'
{ user "go"; text 'A new pull request waits on you. Want it?'; } > "$fx/t.jsonl"
check "an ask outside a Cerebro block goes through" 'passes'
{ user "go"; text "$snag"; user "leave it"; text "Left it."; } > "$fx/t.jsonl"
check "an ask before the user's last message is old" 'passes'
{ user "go"; text "$snag"; } > "$fx/t.jsonl"
opt=false; check "setting off lets it through" 'passes'
opt=0; check "setting 0 lets it through" 'passes'
unset opt
printf 'not json' > "$fx/t.jsonl"
check "a transcript that isn't JSON goes through" 'passes'
check "no transcript goes through" '[ -z "$(echo "{}" | bash "$hook" 2>/dev/null)" ]'
{ user "go"; text $'🧠 **Cerebro**\n- C1: Split the job. Want it?\n  - What it costs: a new pull request and half an hour.'; } > "$fx/t.jsonl"
check "a new pull request named on a question line under the ask is sent back" 'sent_back'
{ user "go"; text $'🧠 **Cerebro**\n- C1: Split the job in a new pull request. Done: #285 is green.\n- C2: Delete the old branch. Waits on a deletion.\n\n🚪 Waiting on you: reply **yes** to C2.'; } > "$fx/t.jsonl"
check "a waiting line that names another proposal goes through" 'passes'
for p in "It needs its own pull request. Want it?" "Needs another PR. Shall I?" "New pull requests, two of them. Should I?" "A follow-up PR. Go ahead?"; do
  { user "go"; text "🧠 **Cerebro**"$'\n'"- C1: Fix CI. $p"; } > "$fx/t.jsonl"
  check "an ask in other words is sent back: $p" 'sent_back'
done
{ user "go"; text $'🧠 **Cerebro**\n- **C1**: Split the job. Want it? A new pull request.'; } > "$fx/t.jsonl"
check "a bold code is read" 'sent_back'
{ user "go"; text $'🧠 **Cerebro**\n* C1: Split the job. Want it? A new pull request.'; } > "$fx/t.jsonl"
check "an asterisk bullet is read" 'sent_back'
for p in "Open a new pull request to delete the old branch. Want it?" "Publish the release in a new pull request. Want it?" "Rotate the shared deploy key. Waits on you: others rely on it." "Change a setting others use. Waits on you: not a new pull request alone."; do
  { user "go"; text "🧠 **Cerebro**"$'\n'"- C1: $p"; } > "$fx/t.jsonl"
  check "a costly ask goes through: $p" 'passes'
done
{ user "go"; text $'🧠 **Cerebro**\n- C1: Split the job. Waits on you: not a pull request, a decision.'; } > "$fx/t.jsonl"
check "a reason that says it is not a pull request goes through" 'passes'
{ user "go"; text $'🧠 **Cerebro**\n- C1: Split the job in a new pull request. Done: #285 is green.\nThe merge is yours. Want it?'; } > "$fx/t.jsonl"
check "an ask on a later line that names no proposal goes through" 'passes'
exit $fail
