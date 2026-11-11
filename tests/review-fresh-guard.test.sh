#!/usr/bin/env bash
# review-fresh-guard's decisions: a hand-off after an unreviewed change is sent
# back, and every other case goes through.
set -u
hook="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/review-fresh-guard.sh"
fx=$(mktemp -d); trap 'rm -rf "$fx"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
user() { jq -nc --arg t "$1" '{type:"user",message:{content:$t}}'; }
text() { jq -nc --arg t "$1" '{type:"assistant",message:{content:[{type:"text",text:$t}]}}'; }
sendmsg() { jq -nc --arg t "$1" '{type:"assistant",message:{content:[{type:"tool_use",name:"SendUserMessage",input:{message:$t}}]}}'; }
tool() { jq -nc --arg n "$1" --argjson i "$2" '{type:"assistant",message:{content:[{type:"tool_use",name:$n,input:$i}]}}'; }
edit() { tool Edit "{\"file_path\":\"$1\"}"; }
bash_() { tool Bash "$(jq -nc --arg c "$1" '{command:$c}')"; }
skill() { tool Skill "{\"skill\":\"$1\"}"; }
agent() { tool Agent "{\"subagent_type\":\"$1\"}"; }
run() { jq -nc --arg t "$fx/t.jsonl" --argjson a "${1:-false}" '{stop_hook_active:$a,transcript_path:$t}' | bash "$hook" 2>/dev/null; }
sent_back() { [ "$(run "${1:-false}" | jq -r '.decision // empty' 2>/dev/null)" = block ]; }
passes() { local out; out=$(run "${1:-false}"); [ $? = 0 ] && [ -z "$out" ]; }
done_="🏁 Done: the X clears the box."
gate="🚪 Waiting on you: press the X in the client."

{ user "go"; edit /repo/a.cs; user "report"; text "$done_"; } > "$fx/t.jsonl"
check "a Done after an edit with no review is sent back" 'sent_back'

{ user "go"; bash_ "git add -A && git commit -m fix"; text "$gate"; } > "$fx/t.jsonl"
check "a gate after a commit with no review is sent back" 'sent_back'

{ user "go"; skill vicky-skills:review; bash_ "git commit -m late"; sendmsg "$done_"; } > "$fx/t.jsonl"
check "a commit after the review, handed over with SendUserMessage, is sent back" 'sent_back'

for r in "skill vicky-skills:review" "skill review" "agent vicky-skills:spec-reviewer" "user '<command-name>/vicky-skills:review</command-name>'"; do
  { user "go"; edit /repo/a.cs; eval "$r"; text "$done_"; } > "$fx/t.jsonl"
  check "a review after the last change lets the hand-off through: $r" 'passes'
done

{ user "go"; edit /tmp/s/notes.md; text "$done_"; } > "$fx/t.jsonl"
check "a scratch edit under /tmp is no change" 'passes'

{ user "go"; bash_ "git log --oneline"; bash_ "git commit-tree x"; text "$done_"; } > "$fx/t.jsonl"
check "a git command that commits nothing is no change" 'passes'

{ user "go"; skill vicky-skills:do; edit /repo/a.cs; text "$done_"; } > "$fx/t.jsonl"
check "another skill is no review" 'sent_back'

{ user "go"; agent Explore; edit /repo/a.cs; text "$done_"; } > "$fx/t.jsonl"
check "another subagent is no review" 'sent_back'

{ user "go"; edit /repo/a.cs; text "Built it. The tests pass, next I push."; } > "$fx/t.jsonl"
check "a reply that hands nothing over goes through" 'passes'

{ user "go"; edit /repo/a.cs; text 'The report starts with `🏁 Done`.'; } > "$fx/t.jsonl"
check "a hand-off marker in quoted code is no hand-off" 'passes'

{ user "go"; text "$done_"; } > "$fx/t.jsonl"
check "a session with no change goes through" 'passes'

{ user "go"; edit /repo/a.cs; text "$done_"; } > "$fx/t.jsonl"
check "the second stop of a turn goes through" 'passes true'
check "the setting off lets it through" 'CLAUDE_PLUGIN_OPTION_GUARD_REVIEW_FRESH=false passes'
check "the setting at 0 lets it through" 'CLAUDE_PLUGIN_OPTION_GUARD_REVIEW_FRESH=0 passes'

check "a missing transcript goes through" 'out=$(jq -nc "{stop_hook_active:false,transcript_path:\"$fx/none\"}" | bash "$hook"); [ -z "$out" ]'
check "bad input goes through" 'out=$(echo "not json" | bash "$hook" 2>/dev/null); [ -z "$out" ]'
exit $fail
