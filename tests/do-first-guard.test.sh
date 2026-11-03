#!/usr/bin/env bash
# do-first-guard refuses an edit to production code until the session has
# started do, and lets tests, docs, a started do and the setting off through.
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
check "a started do lets code through" "" "$(run "$dir/repo/src/app.py" "$dir/do.jsonl")"
check "a typed /do lets code through" "" "$(run "$dir/repo/src/app.py" "$dir/typed.jsonl")"
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
exit $fail
