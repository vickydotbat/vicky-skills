#!/usr/bin/env bash
# do-first-guard refuses an edit to production code until the session has
# started do, or a do build with no approved examples, and lets tests, docs, a do
# with its examples and the setting off through.
set -u
hook="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/do-first-guard.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
git init -q "$dir/repo"; mkdir -p "$dir/repo/src" "$dir/repo/tests"
: > "$dir/none.jsonl"
jq -nc '{type:"assistant",message:{content:[{type:"tool_use",name:"Skill",input:{skill:"vicky-skills:warp"}}]}}' > "$dir/warp.jsonl"
jq -nc '{type:"assistant",message:{content:[{type:"tool_use",name:"Skill",input:{skill:"vicky-skills:do"}}]}}' > "$dir/do.jsonl"
jq -nc '{type:"user",message:{content:"<command-name>/vicky-skills:do</command-name>"}}' > "$dir/typed.jsonl"
fail=0
# The decision, or "exit <n>" when the hook ends with any status but 0.
run() {
  local out code
  out=$(jq -n --arg f "$1" --arg t "$2" '{tool_name:"Edit",tool_input:{file_path:$f},transcript_path:$t}' |
    CLAUDE_PLUGIN_OPTION_STEP_GUARD=${3:-true} bash "$hook"); code=$?
  [ "$code" = 0 ] || { echo "exit $code"; return; }
  jq -r '.hookSpecificOutput.permissionDecision // empty' <<<"$out"
}
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got '$3', want '$2'"; fail=1; fi; }
check "code with no do is refused" deny "$(run "$dir/repo/src/app.py" "$dir/none.jsonl")"
check "a warp alone is no do" deny "$(run "$dir/repo/src/app.ts" "$dir/warp.jsonl")"
check "a new file in a new folder is code too" deny "$(run "$dir/repo/src/new/deep/x.sh" "$dir/none.jsonl")"
check "a started do with no examples is refused" deny "$(run "$dir/repo/src/app.py" "$dir/do.jsonl")"
sk() { jq -nc --arg s "$1" '{type:"assistant",message:{content:[{type:"tool_use",name:"Skill",input:{skill:$s}}]}}'; }
say() { jq -nc --arg t "$1" '{type:"assistant",message:{content:[{type:"text",text:$t}]}}'; }
{ sk vicky-skills:do; sk vicky-skills:examples; } > "$dir/do-ex.jsonl"
{ sk vicky-skills:do; sk red-pen; } > "$dir/do-red.jsonl"
{ sk vicky-skills:do; say "Read the ticket.
Examples: approved on GAME-12"; } > "$dir/do-ticket.jsonl"
{ sk vicky-skills:do; say "Examples: none, because the change is a rename"; } > "$dir/do-none.jsonl"
{ sk vicky-skills:do; say "Examples: none"; } > "$dir/do-bare.jsonl"
{ sk vicky-skills:do; say "Examples: none, because <reason>"; } > "$dir/do-template.jsonl"
{ sk vicky-skills:do; sk vicky-skills:examples; sk vicky-skills:do; } > "$dir/do-again.jsonl"
{ sk vicky-skills:examples; sk vicky-skills:do; } > "$dir/ex-before.jsonl"
{ sk spark-joy; sk vicky-skills:do; } > "$dir/joy-do.jsonl"
check "an examples start alone is no tick" deny "$(run "$dir/repo/src/app.py" "$dir/do-ex.jsonl")"
check "a red-pen start alone is no tick" deny "$(run "$dir/repo/src/app.py" "$dir/do-red.jsonl")"
check "a line claiming approval on a ticket is no tick" deny "$(run "$dir/repo/src/app.py" "$dir/do-ticket.jsonl")"
check "a do that needs no example, with its reason, lets code through" "" "$(run "$dir/repo/src/app.py" "$dir/do-none.jsonl")"
check "a no-example line without its reason is refused" deny "$(run "$dir/repo/src/app.py" "$dir/do-bare.jsonl")"
check "a quoted template line is no reason" deny "$(run "$dir/repo/src/app.py" "$dir/do-template.jsonl")"
check "a second do needs its own examples" deny "$(run "$dir/repo/src/app.py" "$dir/do-again.jsonl")"
check "examples before the do don't count" deny "$(run "$dir/repo/src/app.py" "$dir/ex-before.jsonl")"
check "a do after spark-joy still needs examples" deny "$(run "$dir/repo/src/app.py" "$dir/joy-do.jsonl")"
check "the examples refusal steers to the examples skill" 1 "$(jq -n --arg f "$dir/repo/src/app.py" --arg t "$dir/do.jsonl" '{tool_name:"Edit",tool_input:{file_path:$f},transcript_path:$t}' | CLAUDE_PLUGIN_OPTION_STEP_GUARD=true bash "$hook" | grep -c 'Run the examples skill')"
jq -nc '{type:"assistant",message:{content:[{type:"tool_use",name:"Skill",input:{skill:"spark-joy"}}]}}' > "$dir/joy.jsonl"
check "a spark-joy run lets code through" "" "$(run "$dir/repo/src/app.py" "$dir/joy.jsonl")"
check "a typed /do counts as a do start" 1 "$(jq -n --arg f "$dir/repo/src/app.py" --arg t "$dir/typed.jsonl" '{tool_name:"Edit",tool_input:{file_path:$f},transcript_path:$t}' | CLAUDE_PLUGIN_OPTION_STEP_GUARD=true bash "$hook" | grep -c 'no approved examples yet')"
check "a test folder passes" "" "$(run "$dir/repo/tests/app.sh" "$dir/none.jsonl")"
check "a test file by name passes" "" "$(run "$dir/repo/src/app.test.tsx" "$dir/none.jsonl")"
check "a test file by underscore name passes" "" "$(run "$dir/repo/src/app_test.go" "$dir/none.jsonl")"
check "a name holding test inside a word is code" deny "$(run "$dir/repo/src/latest.py" "$dir/none.jsonl")"
check "a doc passes" "" "$(run "$dir/repo/README.md" "$dir/none.jsonl")"
check "a file outside git passes" "" "$(run "$dir/loose.py" "$dir/none.jsonl")"
check "a missing transcript passes" "" "$(run "$dir/repo/src/app.py" "$dir/gone.jsonl")"
check "the setting off passes" "" "$(run "$dir/repo/src/app.py" "$dir/none.jsonl" false)"
check "no file path passes" "" "$(jq -n '{tool_name:"Edit",tool_input:{}}' | CLAUDE_PLUGIN_OPTION_STEP_GUARD=true bash "$hook")"
check "the refusal steers to do" 1 "$(jq -n --arg f "$dir/repo/src/app.py" --arg t "$dir/none.jsonl" '{tool_name:"Edit",tool_input:{file_path:$f},transcript_path:$t}' | CLAUDE_PLUGIN_OPTION_STEP_GUARD=true bash "$hook" | grep -c 'start do on the change now')"
# A reply line sent through SendUserMessage counts, as brief mode sends every reply there.
jq -nc '{type:"assistant",message:{content:[{type:"tool_use",name:"Skill",input:{skill:"vicky-skills:do"}}]}}' > "$dir/sum.jsonl"
jq -nc '{type:"assistant",message:{content:[{type:"tool_use",name:"SendUserMessage",input:{message:"Examples: none, because found work: review findings on #1490\nGiven a reload\nWhen it runs twice\nThen it loads once"}}]}}' >> "$dir/sum.jsonl"
mkdir -p "$dir/repo/server/src/Core" "$dir/repo/server/src/IntegrationTests/Reload"
check "a found-work line in a SendUserMessage lets the edit through" "" "$(run "$dir/repo/server/src/Core/Thing.cs" "$dir/sum.jsonl")"
jq -nc '{type:"assistant",message:{content:[{type:"tool_use",name:"Skill",input:{skill:"vicky-skills:do"}}]}}' > "$dir/donly.jsonl"
check "a file in an IntegrationTests folder is a test" "" "$(run "$dir/repo/server/src/IntegrationTests/Reload/ReloadExamples.cs" "$dir/donly.jsonl")"
check "the same file outside a test folder is still held" deny "$(run "$dir/repo/server/src/Core/Thing.cs" "$dir/donly.jsonl")"
mkdir -p "$dir/repo/plugins/p/evals/skill/case"
check "an eval case's scaffold is a test" "" "$(run "$dir/repo/plugins/p/evals/skill/case/scaffold.sh" "$dir/donly.jsonl")"
check "a script beside an evals folder is still code" deny "$(run "$dir/repo/plugins/p/evaluate.sh" "$dir/donly.jsonl")"
exit $fail
