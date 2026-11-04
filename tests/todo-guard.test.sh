#!/usr/bin/env bash
# todo-guard refuses a write to .todo until standing-orders has started, and
# lets reads, other files, a started standing-orders and the setting off through.
set -u
hook="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/todo-guard.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
: > "$dir/none.jsonl"
jq -nc '{type:"assistant",message:{content:[{type:"tool_use",name:"Skill",input:{skill:"vicky-skills:standing-orders"}}]}}' > "$dir/so.jsonl"
fail=0
run() { # tool, field json, transcript
  jq -n --arg t "$1" --argjson i "$2" --arg p "$3" '{tool_name:$t,tool_input:$i,transcript_path:$p}' |
    CLAUDE_PLUGIN_OPTION_GUARD_TODO_NEXT=${OPT:-true} bash "$hook" > "$dir/out"; local code=$?
  [ "$code" = 0 ] || { echo "exit $code"; return; }; jq -r '.hookSpecificOutput.permissionDecision // empty' < "$dir/out"
}
cmd() { jq -nc --arg c "$1" '{command:$c}'; }
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got '$3', want '$2'"; fail=1; fi; }
check "an Edit to .todo refuses" deny "$(run Edit '{"file_path":"/r/.todo"}' "$dir/none.jsonl")"
check "a Write to .todo refuses" deny "$(run Write '{"file_path":".todo"}' "$dir/none.jsonl")"
for c in "echo x >> .todo" "printf x > ./.todo" "echo x | tee -a .todo" "sed -i 1d .todo" "rm .todo" "mv a .todo"; do
  check "a shell write refuses: $c" deny "$(run Bash "$(cmd "$c")" "$dir/none.jsonl")"
done
check "after standing-orders an Edit passes" "" "$(run Edit '{"file_path":".todo"}' "$dir/so.jsonl")"
check "after standing-orders a shell write passes" "" "$(run Bash "$(cmd "echo x >> .todo")" "$dir/so.jsonl")"
{ cat "$dir/so.jsonl"; jq -nc '{type:"user",message:{content:"next ask"}}'; } > "$dir/old.jsonl"
check "a standing-orders before the user's last message does not count" deny "$(run Edit '{"file_path":".todo"}' "$dir/old.jsonl")"
{ jq -nc '{type:"user",message:{content:"go"}}'; cat "$dir/so.jsonl"; jq -nc '{type:"user",isMeta:true,message:{content:[{type:"text",text:"Base directory for this skill"}]}}'; } > "$dir/meta.jsonl"
check "the skill text Claude Code injects after standing-orders is no user message" "" "$(run Edit '{"file_path":".todo"}' "$dir/meta.jsonl")"
check "a read passes" "" "$(run Bash "$(cmd "cat .todo")" "$dir/none.jsonl")"
check "a grep passes" "" "$(run Bash "$(cmd "grep -n GAME .todo")" "$dir/none.jsonl")"
check "another file passes" "" "$(run Edit '{"file_path":"x.todo.md"}' "$dir/none.jsonl")"
check "rm of another file passes" "" "$(run Bash "$(cmd "rm notes.txt")" "$dir/none.jsonl")"
check "a Read passes" "" "$(run Read '{"file_path":".todo"}' "$dir/none.jsonl")"
check "a missing transcript refuses" deny "$(run Edit '{"file_path":".todo"}' "$dir/nope.jsonl")"
check "the setting off passes" "" "$(OPT=false run Edit '{"file_path":".todo"}' "$dir/none.jsonl")"
check "the setting 0 passes" "" "$(OPT=0 run Edit '{"file_path":".todo"}' "$dir/none.jsonl")"
check "bad input passes" "" "$(echo nope | bash "$hook")"
exit $fail
