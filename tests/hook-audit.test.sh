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
exit $fail
