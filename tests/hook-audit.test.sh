#!/usr/bin/env bash
# hook-audit.py counts a hook's refusals and sorts what the agent did next.
set -u
audit="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/skills/engineering/captains-log/scripts/hook-audit.py"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
fail=0
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got '$3', want '$2'"; fail=1; fi; }
use() { jq -nc --arg id "$1" --arg c "$2" '{type:"assistant",message:{content:[{type:"tool_use",id:$id,name:"Bash",input:{command:$c}}]}}'; }
res() { jq -nc --arg id "$1" --arg t "$2" '{type:"user",message:{content:[{type:"tool_result",tool_use_id:$id,content:$t}]}}'; }
refused='PreToolUse:Bash hook error: ["/x/scripts/demo-guard.sh"]: no'
mkdir -p "$dir/p"
{ use a "ls -la one"; res a "$refused"; use b "ls -la one two"; res b ok
  use c "rm x"; res c "$refused"; use d "rm x"; res d "$refused"
  jq -nc '{type:"user",message:{content:"stop"}}'; } > "$dir/p/s.jsonl"
check "refusals and outcomes are counted per hook" "refusals=3 retry-passed=1 retry-refused=1 stopped=1" "$(python3 -I "$audit" 30 "$dir" | tr " " "\n" | sed 1d | sort | tr "\n" " " | sed "s/ $//")"
check "no logs says so" "no hook refusals in 30 days" "$(python3 -I "$audit" 30 "$dir/none")"
skill() { jq -nc --arg id "$1" '{type:"assistant",message:{content:[{type:"tool_use",id:$id,name:"Skill",input:{skill:"x"}}]}}'; }
said() { jq -nc --arg t "$1" '{type:"user",message:{content:[{type:"text",text:$t}]}}'; }
mkdir -p "$dir/q"
{ echo "not json"
  use e "make test"; res e "$refused"; jq -nc '{type:"user",message:{content:"wait"}}'; use f "make test"; res f ok
  use g "make lint"; res g "$refused"; said "hold on"; use h "make lint"; res h ok
  use i "git push origin"; res i "$refused"; use j "cat README.md"; res j ok
  use k "git push origin"; res k "$refused"; use l "cat CHANGES.md"; res l "$refused"
  use m "rm -rf build"; res m "$refused"; skill n; res n ok
  use o "rm -rf dist"; res o "$refused"; skill p; } > "$dir/q/s.jsonl"
check "a user turn, typed or as text, ends the search; another call, another refusal and a skill each count" \
  "other-call=1 other-refused=1 refusals=7 retry-refused=1 skill=2 stopped=2" "$(python3 -I "$audit" 30 "$dir/q" | tr " " "\n" | sed 1d | sort | tr "\n" " " | sed "s/ $//")"
mkdir -p "$dir/old"; cp "$dir/p/s.jsonl" "$dir/old/s.jsonl"; touch -d "60 days ago" "$dir/old/s.jsonl"
check "a log older than the window is left out" "no hook refusals in 30 days" "$(python3 -I "$audit" 30 "$dir/old")"
check "with no arguments it reads 30 days of the user's logs" "no hook refusals in 30 days" "$(HOME="$dir/home" python3 -I "$audit")"
mkdir -p "$dir/r"
{ use s "make docs"; res s "$refused"; jq -nc '{type:"assistant",message:{content:[{type:"text",text:"Trying again."}]}}'; use t "make docs"; res t ok; } > "$dir/r/s.jsonl"
check "the agent's own words don't end the search" "refusals=1 retry-passed=1" "$(python3 -I "$audit" 30 "$dir/r" | tr " " "\n" | sed 1d | sort | tr "\n" " " | sed "s/ $//")"
exit $fail
