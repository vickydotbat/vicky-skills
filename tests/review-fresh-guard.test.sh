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
done_="🚪 Waiting on you: the X clears the box."
gate="🚪 Waiting on you: press the X in the client."

{ user "go"; edit /repo/a.cs; user "report"; text "$done_"; } > "$fx/t.jsonl"
check "a Done after an edit with no review is sent back" 'sent_back'

{ user "go"; bash_ "git add -A && git commit -m fix"; text "$gate"; } > "$fx/t.jsonl"
check "a gate after a commit with no review is sent back" 'sent_back'

{ user "go"; skill vicky-skills:review; bash_ "git commit -m late"; sendmsg "$done_"; } > "$fx/t.jsonl"
check "a commit after the review, handed over with SendUserMessage, is sent back" 'sent_back'

for c in Write MultiEdit; do
  { user "go"; tool "$c" '{"file_path":"/repo/b.cs"}'; text "$done_"; } > "$fx/t.jsonl"
  check "a change with no review is sent back: $c" 'sent_back'
done

for r in "user '<command-name>/review</command-name>'" "skill vicky-skills:review" "skill review" "agent vicky-skills:spec-reviewer" "user '<command-name>/vicky-skills:review</command-name>'"; do
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

{ user "go"; edit /repo/a.cs; text 'The report starts with `🚪 Waiting on you:`.'; } > "$fx/t.jsonl"
check "a hand-off marker in quoted code is no hand-off" 'passes'

{ user "go"; edit /repo/a.cs; text "🏁 Done: finished."; } > "$fx/t.jsonl"
check "a Done line is no hand-off any more" 'passes'

{ user "go"; text "$done_"; } > "$fx/t.jsonl"
check "a session with no change goes through" 'passes'

{ user "go"; edit /repo/a.cs; text "$done_"; } > "$fx/t.jsonl"
check "the second stop of a turn goes through" 'passes true'
check "the setting off lets it through" 'CLAUDE_PLUGIN_OPTION_GUARD_REVIEW_FRESH=false passes'
check "the setting at 0 lets it through" 'CLAUDE_PLUGIN_OPTION_GUARD_REVIEW_FRESH=0 passes'

for c in "sed -i s/a/b/ src/a.cs" "cat > src/a.cs <<'X'" "echo x | tee src/a.cs" "cp a b" "git apply fix.patch" "git rebase origin/main" "perl -pi -e s/a/b/ f" "sed --in-place s/a/b/ f" "rm src/a.cs" "run0 cp a b" "env X=1 mv a b" "dd if=a of=b" "git restore f" "git stash pop"; do
  { user "go"; bash_ "$c"; text "$done_"; } > "$fx/t.jsonl"
  check "a shell write with no review is sent back: $c" 'sent_back'
done
for c in "ls 2>/dev/null" "cat a > /tmp/s/out" "make 2>&1 | tail" "git status"; do
  { user "go"; bash_ "$c"; text "$done_"; } > "$fx/t.jsonl"
  check "a shell command that writes no repo file goes through: $c" 'passes'
done
{ user "go"; tool NotebookEdit '{"notebook_path":"/repo/n.ipynb"}'; text "$done_"; } > "$fx/t.jsonl"
check "a notebook edit with no review is sent back" 'sent_back'
{ jq -nc '{type:"user",message:{content:[{type:"text",text:"<command-name>/review</command-name>"}]}}'; } > "$fx/u.jsonl"
{ user "go"; edit /repo/a.cs; cat "$fx/u.jsonl"; text "$done_"; } > "$fx/t.jsonl"
check "a typed /review in block form counts as a review" 'passes'

pre() { jq -nc --arg t "$fx/t.jsonl" --arg s "$1" '{hook_event_name:"PreToolUse",tool_name:"Skill",tool_input:{skill:$s},transcript_path:$t}' | bash "$hook" 2>/dev/null; }
denied() { [ "$(pre "$1" | jq -r '.hookSpecificOutput.permissionDecision // empty' 2>/dev/null)" = deny ]; }
{ user "go"; edit /repo/a.cs; } > "$fx/t.jsonl"
check "over-to-you after an unreviewed change is refused" 'denied vicky-skills:over-to-you'
check "another skill after an unreviewed change runs" '[ -z "$(pre vicky-skills:review)" ]'
check "a skill whose name only holds over-to-you runs" '[ -z "$(pre my-over-to-you-x)" ]'
check "over-to-you with the setting off runs" '[ -z "$(CLAUDE_PLUGIN_OPTION_GUARD_REVIEW_FRESH=false pre vicky-skills:over-to-you)" ]'
{ user "go"; edit /repo/a.cs; skill vicky-skills:review; } > "$fx/t.jsonl"
check "over-to-you after a review runs" '[ -z "$(pre vicky-skills:over-to-you)" ]'
check "over-to-you with a missing transcript runs" 'out=$(jq -nc "{hook_event_name:\"PreToolUse\",tool_input:{skill:\"over-to-you\"},transcript_path:\"$fx/none\"}" | bash "$hook"); [ -z "$out" ]'

check "a missing transcript goes through" 'out=$(jq -nc "{stop_hook_active:false,transcript_path:\"$fx/none\"}" | bash "$hook"); [ -z "$out" ]'
check "bad input goes through" 'out=$(echo "not json" | bash "$hook" 2>/dev/null); [ -z "$out" ]'
exit $fail
