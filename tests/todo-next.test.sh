#!/usr/bin/env bash
# todo-next blocks a reply that names what comes next when standing-orders has
# not run since the user's last message, and lets a jotted reply, a "Next:
# nothing", a reply with no next, a repo with standing orders off, the second
# stop and the setting off through.
set -u
hook="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/todo-next.sh"
fx=$(mktemp -d); trap 'rm -rf "$fx"' EXIT
git -C "$fx" init -q; echo .todo > "$fx/.gitignore"
mkdir -p "$fx/off/docs/agents"; git -C "$fx/off" init -q; echo .todo > "$fx/off/.gitignore"; echo 'Todo file: off' > "$fx/off/docs/agents/x.md"
mkdir "$fx/tracked"; git -C "$fx/tracked" init -q
fail=0
user() { jq -nc --arg t "$1" '{type:"user",message:{content:$t}}'; }
sent() { jq -nc --arg t "$1" '{type:"assistant",message:{content:[{type:"tool_use",name:"SendUserMessage",input:{message:$t}}]}}'; }
skill() { jq -nc --arg s "$1" '{type:"assistant",message:{content:[{type:"tool_use",name:"Skill",input:{skill:$s}}]}}'; }
edit() { jq -nc '{type:"assistant",message:{content:[{type:"tool_use",name:"Edit",input:{file_path:".todo"}}]}}'; }
stop() { local out code; out=$(jq -nc --arg t "$fx/t.jsonl" --argjson a "${1:-false}" '{stop_hook_active:$a,transcript_path:$t}' |
  CLAUDE_PROJECT_DIR=${DIR:-$fx} CLAUDE_PLUGIN_OPTION_GUARD_TODO_NEXT=${OPT:-true} bash "$hook"); code=$?
  [ "$code" = 0 ] || { echo "exit $code"; return; }; jq -r '.decision // empty' <<<"$out"; }
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got '$3', want '$2'"; fail=1; fi; }
for r in "**Next:** build GAME-2531" "Next: the merge" "My pick for next: the tail channels" "Still want the sort?"; do
  { user go; sent "Done. $r"; } > "$fx/t.jsonl"
  check "unjotted blocks: $r" block "$(stop)"
done
{ user go; sent "Done. Next: build GAME-2531"; } > "$fx/t.jsonl"
check "the steer quotes the line" 1 "$(jq -nc --arg t "$fx/t.jsonl" '{transcript_path:$t}' | CLAUDE_PROJECT_DIR=$fx bash "$hook" | jq -r .reason | grep -c 'build GAME-2531')"
{ user go; skill vicky-skills:standing-orders; sent "Next: build GAME-2531"; } > "$fx/t.jsonl"
check "a started standing-orders passes" "" "$(stop)"
{ user go; skill vicky-skills:standing-orders; jq -nc '{type:"user",isMeta:true,message:{content:[{type:"text",text:"Base directory for this skill"}]}}'; sent "Next: build GAME-2531"; } > "$fx/t.jsonl"
check "the skill text Claude Code injects is no user message" "" "$(stop)"
{ user go; edit; sent "Next: build GAME-2531"; } > "$fx/t.jsonl"
check "an Edit to .todo is no jot" block "$(stop)"
{ user go; skill vicky-skills:standing-orders; user again; sent "Next: build GAME-2531"; } > "$fx/t.jsonl"
check "a jot before the user's last message does not count" block "$(stop)"
{ user go; skill vicky-skills:do; sent "Next: build GAME-2531"; } > "$fx/t.jsonl"
check "another skill is no jot" block "$(stop)"
for r in "Next: nothing" "**Next:** none" "Done, all merged." "The next run passed." 'Ran `Next: x`'; do
  { user go; sent "$r"; } > "$fx/t.jsonl"
  check "no item passes: $r" "" "$(stop)"
done
{ user go; sent "Next: build GAME-2531"; } > "$fx/t.jsonl"
check "the second stop passes" "" "$(stop true)"
check "Todo file: off passes" "" "$(DIR=$fx/off stop)"
check "a repo that tracks .todo passes" "" "$(DIR=$fx/tracked stop)"
check "the setting off passes" "" "$(OPT=false stop)"
check "a missing project folder passes" "" "$(DIR=$fx/nope stop)"
check "the setting 0 passes" "" "$(OPT=0 stop)"
check "a missing transcript passes" "" "$(jq -nc '{transcript_path:"/nope"}' | CLAUDE_PROJECT_DIR=$fx bash "$hook")"
exit $fail
