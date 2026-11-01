#!/usr/bin/env bash
# The never-a-V1 hook's decisions beyond its approved examples: what counts as
# the agent's last reply, the once-per-turn steer, and bad input.
set -u
hook="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/no-v1.sh"
fx=$(mktemp -d); trap 'rm -rf "$fx"' EXIT
export CLAUDE_PLUGIN_OPTION_GUARD_NO_V1=true
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
user() { jq -nc --arg t "$1" '{type:"user",message:{content:$t}}'; }
text() { jq -nc --arg t "$1" '{type:"assistant",message:{content:[{type:"text",text:$t}]}}'; }
sent() { jq -nc --arg t "$1" '{type:"assistant",message:{content:[{type:"tool_use",name:"SendUserMessage",input:{message:$t}}]}}'; }
result() { jq -nc '{type:"user",message:{content:[{type:"tool_result",content:"ok"}]}}'; }
stop() { jq -nc --arg t "$fx/t.jsonl" --argjson a "${1:-false}" '{stop_hook_active:$a,transcript_path:$t}' | bash "$hook"; }
blocked() { stop | jq -e '.decision == "block"' >/dev/null 2>&1; }
{ user "go"; sent "Done. Sorting could be a follow-up PR."; } > "$fx/t.jsonl"
check "a SendUserMessage offer is stopped" 'blocked'
check "the steer names the sentence" 'stop | jq -r .reason | grep -q "Sorting could be a follow-up PR."'
check "a second stop in the same turn goes through" '[ -z "$(stop true)" ]'
{ user "go"; text "Sorting could be a follow-up PR."; user "no, do it here"; text "Done, sorting is in."; } > "$fx/t.jsonl"
check "an offer before the user's last message is not read again" '[ -z "$(stop)" ]'
{ user "go"; text "Next, a follow-up PR?"; result; text "Done."; } > "$fx/t.jsonl"
check "a tool result does not end the reply" 'blocked'
{ user "go"; text "Want me to fold it in, or leave it?"; } > "$fx/t.jsonl"
check "a fold-in-or question is stopped" 'blocked'
{ user "go"; text "The next ticket on the chart is GAME-7, and I closed GAME-6."; } > "$fx/t.jsonl"
check "naming the next ticket on a chart is no offer" '[ -z "$(stop)" ]'
for r in "That's a different hook, so I left it out of this PR." "I kept them out of the pull request." "Still want #74 fixed next, in its own PR? My pick is yes." "Each one can go in their own pull request." "Should I take issue 12 next?" "Want me to fix ticket 5 too?" "Should I build #9?"; do
  { user "go"; text "$r"; } > "$fx/t.jsonl"
  check "an open ticket kept out or offered is stopped: $r" 'blocked'
done
for r in "Want me to rename the variable?" "Should I fix the issue in the parser?" "Still want the ticket link?" "It follows its own PR template."; do
  { user "go"; text "$r"; } > "$fx/t.jsonl"
  check "a sentence that offers no ticket goes through: $r" '[ -z "$(stop)" ]'
done
check "the steer points at open tickets and the summit" '{ user "go"; text "Should I take issue 12 next?"; } > "$fx/t.jsonl"; stop | jq -r .reason | grep -q "every open ticket here that waits on no one" && stop | jq -r .reason | grep -q "summit"'
{ user "go"; text "All done."; } > "$fx/t.jsonl"
check "a plain reply goes through" '[ -z "$(stop)" ]'
check "a missing transcript goes through" '[ -z "$(jq -nc "{transcript_path:\"$fx/none\"}" | bash "$hook")" ]'
check "a plain reply exits 0" '{ user "go"; text "All done."; } > "$fx/t.jsonl"; stop >/dev/null; [ $? = 0 ]'
check "a missing transcript exits 0" 'jq -nc "{transcript_path:\"$fx/none\"}" | bash "$hook"; [ $? = 0 ]'
check "bad input goes through and exits 0" 'echo "not json" | bash "$hook"; [ $? = 0 ]'
check "the setting at 1 is on" '{ user "go"; text "A follow-up PR can do it."; } > "$fx/t.jsonl"; CLAUDE_PLUGIN_OPTION_GUARD_NO_V1=1 stop | grep -q block'
exit $fail
