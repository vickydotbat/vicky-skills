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
building() { jq -nc --arg s "${1:-vicky-skills:do}" '{type:"assistant",message:{content:[{type:"tool_use",name:"Skill",input:{skill:$s}}]}}'; }
# Every fixture is a building session (do started first) unless PLANNING is set.
stop() {
  if [ -z "${PLANNING:-}" ]; then { building; cat "$fx/t.jsonl"; } > "$fx/b.jsonl"; else cp "$fx/t.jsonl" "$fx/b.jsonl"; fi
  jq -nc --arg t "$fx/b.jsonl" --argjson a "${1:-false}" '{stop_hook_active:$a,transcript_path:$t}' | bash "$hook"
}
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
for r in "Those can be follow-up tickets." "That's a different hook, so I left it out of this PR." "I kept them out of the pull request." "Still want #74 fixed next, in its own PR? My pick is yes." "Each one can go in their own pull request." "Should I take issue 12 next?" "Want me to fix ticket 5 too?" "Should I build #9?"; do
  { user "go"; text "$r"; } > "$fx/t.jsonl"
  check "an open ticket kept out or offered is stopped: $r" 'blocked'
done
for r in "Surprises are logged, so later charts name them as risks." "The approach is fine for later." "Want me to rename the variable?" "Should I fix the issue in the parser?" "Still want the ticket link?" "It follows its own PR template."; do
  { user "go"; text "$r"; } > "$fx/t.jsonl"
  check "a sentence that offers no ticket goes through: $r" '[ -z "$(stop)" ]'
done
check "the steer points at open tickets and the summit" '{ user "go"; text "Should I take issue 12 next?"; } > "$fx/t.jsonl"; stop | jq -r .reason | grep -q "every open ticket here that waits on no one" && stop | jq -r .reason | grep -q "summit"'
for r in "Sorting waits until v2." "That is next v2 work." "Leave it for the later v2." "It can go into v2." "Defer it to v2." "Push it to v2."; do
  { user "go"; text "$r"; } > "$fx/t.jsonl"
  check "a v2 after its lead word is an offer: $r" 'blocked'
done
for r in "Plurals like \"follow-up tickets\" still get caught." "It matched “a pull request for later” too." "V2: the hook has no memory." "**V2.** Done." "We shipped v2 of the parser today." "The hook reads \`a follow-up PR\` as an offer."; do
  { user "go"; text "$r"; } > "$fx/t.jsonl"
  check "a label, a past v2 or quoted code is no offer: $r" '[ -z "$(stop)" ]'
done
{ user "go"; text "All done."; } > "$fx/t.jsonl"
check "a plain reply goes through" '[ -z "$(stop)" ]'
check "a missing transcript goes through" '[ -z "$(jq -nc "{transcript_path:\"$fx/none\"}" | bash "$hook")" ]'
check "a plain reply exits 0" '{ user "go"; text "All done."; } > "$fx/t.jsonl"; stop >/dev/null; [ $? = 0 ]'
{ user "maybe not here, but in a different PR, depot PRs only get the assets CI"; text "It goes in its own PR, off fresh main."; } > "$fx/t.jsonl"
check "a pull request of its own the user asked for goes through" 'out=$(stop); [ $? = 0 ] && [ -z "$out" ]'
{ user "go"; text "I told them to trigger only on deferral words like 'later' or 'follow-up PR'."; } > "$fx/t.jsonl"
check "words in single quotes are a mention" '[ -z "$(stop)" ]'
{ user "go"; text "I'd say it's best left as a follow-up PR, isn't it."; } > "$fx/t.jsonl"
check "apostrophes in words keep the offer in view" 'blocked'
{ user "go"; tool=$(jq -nc '{type:"user",message:{content:[{type:"text",text:"make a separate PR for it"}]}}'); echo "$tool"; text "It goes in its own PR."; } > "$fx/t.jsonl"
check "the ask is read from a message of text blocks too" '[ -z "$(stop)" ]'
check "a missing transcript exits 0" 'jq -nc "{transcript_path:\"$fx/none\"}" | bash "$hook"; [ $? = 0 ]'
check "bad input goes through and exits 0" 'echo "not json" | bash "$hook"; [ $? = 0 ]'
check "the setting at 1 is on" '{ user "go"; text "A follow-up PR can do it."; } > "$fx/t.jsonl"; CLAUDE_PLUGIN_OPTION_GUARD_NO_V1=1 stop | grep -q block'
# Found work folds into an effort only while one is built: a session where do
# or warp never started is planning, and its replies go through.
{ user "file the tickets"; text "Next up is GAME-2513, the only one that isn't waiting on another ticket."; } > "$fx/t.jsonl"
check "a planning session's reply goes through" 'out=$(PLANNING=1 stop); [ $? = 0 ] && [ -z "$out" ]'
{ user "go"; text "Sorting could be a follow-up PR."; } > "$fx/t.jsonl"
check "an offer in a session that never started do goes through" 'out=$(PLANNING=1 stop); [ $? = 0 ] && [ -z "$out" ]'
{ building vicky-skills:warp; user "go"; text "Sorting could be a follow-up PR."; } > "$fx/t.jsonl"
check "an offer in a warp is sent back" 'PLANNING=1 stop | jq -e ".decision == \"block\"" >/dev/null'
{ user "<command-name>/vicky-skills:do</command-name>"; text "Sorting could be a follow-up PR."; } > "$fx/t.jsonl"
check "an offer after the user typed /do is sent back" 'PLANNING=1 stop | jq -e ".decision == \"block\"" >/dev/null'
{ building vicky-skills:mission-brief; user "go"; text "Sorting could be a follow-up PR."; } > "$fx/t.jsonl"
check "another skill does not count as building" 'out=$(PLANNING=1 stop); [ $? = 0 ] && [ -z "$out" ]'
# A Next list that waits on no one is work to start now.
{ user "do the handoff, then the full review"; text "Findings are posted on the PR."; text "**Next:** fix S1 to C3, then the second review."; } > "$fx/t.jsonl"
check "a reply that ends on a Next list is sent back" 'blocked'
check "the steer says to start the list now" 'stop | jq -r .reason | grep -q "Start its first item in this turn"'
check "the Next steer is one decision and exits 0" 'out=$(stop); [ $? = 0 ] && [ "$(jq -s length <<<"$out")" = 1 ]'
{ user "go"; text "🚪 Waiting on you: Q1, keep the old branches?"; text "**Next**: fix S1 to C3."; } > "$fx/t.jsonl"
check "a wait elsewhere in the reply leaves a Next list that waits on no one" 'blocked'
for r in "Next: merge #12 once CI is green." "Next: the sitting, which waits on you." "Next up, want me to take the cloak?" "Next: after it merges, I stage the server."; do
  { user "go"; text "$r"; } > "$fx/t.jsonl"
  check "a Next list with a wait or a question goes through: $r" 'out=$(stop); [ $? = 0 ] && [ -z "$out" ]'
done
{ user "go"; text "Next: fix S1."; text "S1 is fixed, and the tests pass."; } > "$fx/t.jsonl"
check "a checkpoint's Next list the turn then finished goes through" 'out=$(stop); [ $? = 0 ] && [ -z "$out" ]'
{ user "go"; text "Next, each example comes to you as a page to approve."; } > "$fx/t.jsonl"
check "a Next list that hands something to the user goes through" 'out=$(stop); [ $? = 0 ] && [ -z "$out" ]'
{ user "/vicky-skills:conn hand it off"; text "Next: fix S1, then the review."; } > "$fx/t.jsonl"
check "a handoff's Next list goes through" 'out=$(stop); [ $? = 0 ] && [ -z "$out" ]'
{ user "go"; text "The next ticket is GAME-7."; } > "$fx/t.jsonl"
check "a sentence that only mentions next goes through" 'out=$(stop); [ $? = 0 ] && [ -z "$out" ]'
{ user "go"; text "Fixed it."; } > "$fx/t.jsonl"
check "a Next list in a planning session goes through" '{ user "plan it"; text "Next: fix S1."; } > "$fx/t.jsonl"; out=$(PLANNING=1 stop); [ $? = 0 ] && [ -z "$out" ]'
exit $fail
