#!/usr/bin/env bash
# same-refusal refuses a call identical to the call just before it when a hook
# refused that one, and lets a changed call, a call after another step, a call
# after a success, a missing transcript, bad input and the setting off through.
set -u
hook="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/same-refusal.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
fail=0
use() { jq -nc --arg id "$1" --arg n "$2" --argjson i "$3" '{type:"assistant",message:{content:[{type:"tool_use",id:$id,name:$n,input:$i}]}}'; }
res() { jq -nc --arg id "$1" --arg c "$2" --argjson e "$3" '{type:"user",message:{content:[{type:"tool_result",tool_use_id:$id,content:$c,is_error:$e}]}}'; }
push='{"command":"git push"}'
run() { jq -nc --arg t "$1" --arg n "$2" --argjson i "$3" '{tool_name:$n,tool_input:$i,transcript_path:$t,tool_use_id:"now"}' |
  CLAUDE_PLUGIN_OPTION_GUARD_SAME_REFUSAL=${OPT:-true} bash "$hook" > "$dir/out"; local c=$?
  [ "$c" = 0 ] || { echo "exit $c"; return; }; jq -r '.hookSpecificOutput.permissionDecision // empty' < "$dir/out"; }
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got '$3', want '$2'"; fail=1; fi; }
{ use a Bash "$push"; res a 'PreToolUse:Bash hook error: push-behind-guard: refused' true; } > "$dir/refused.jsonl"
check "the same call right after a hook refused it is refused" deny "$(run "$dir/refused.jsonl" Bash "$push")"
check "the refusal says to do what the first one said" 1 "$(run "$dir/refused.jsonl" Bash "$push" >/dev/null; grep -c 'do what it says first' "$dir/out")"
check "a changed call passes" "" "$(run "$dir/refused.jsonl" Bash '{"command":"git push --force-with-lease"}')"
check "another tool with the same input passes" "" "$(run "$dir/refused.jsonl" Edit "$push")"
{ cat "$dir/refused.jsonl"; use b Bash '{"command":"git rebase origin/main"}'; res b 'ok' false; } > "$dir/between.jsonl"
check "the same call after another step passes" "" "$(run "$dir/between.jsonl" Bash "$push")"
{ use a Bash "$push"; res a 'Everything up-to-date' false; } > "$dir/ok.jsonl"
check "the same call after a success passes" "" "$(run "$dir/ok.jsonl" Bash "$push")"
{ use a Bash "$push"; res a 'exit 1: rejected by remote' true; } > "$dir/err.jsonl"
check "a call that failed on its own, not by a hook, passes" "" "$(run "$dir/err.jsonl" Bash "$push")"
{ use a Edit '{"file_path":"x.cs","old_string":"a","new_string":"b"}'; res a 'PreToolUse:Edit hook error: x.cs is production code' true; } > "$dir/edit.jsonl"
{ use a Bash "$push"; res a 'ssh: connect to host: Connection refused' true; } > "$dir/net.jsonl"
check "a retry after a refused network connection passes" "" "$(run "$dir/net.jsonl" Bash "$push")"
check "a refused Edit repeated is refused" deny "$(run "$dir/edit.jsonl" Edit '{"file_path":"x.cs","old_string":"a","new_string":"b"}')"
: > "$dir/empty.jsonl"
{ cat "$dir/refused.jsonl"; use now Bash "$push"; } > "$dir/written.jsonl"
check "the current call already in the transcript is skipped by its id" deny "$(run "$dir/written.jsonl" Bash "$push")"
{ cat "$dir/refused.jsonl"; use other Bash "$push"; } > "$dir/inflight.jsonl"
check "an in-flight call with no result, under another id, is skipped" deny "$(run "$dir/inflight.jsonl" Bash "$push")"
check "a transcript with no call passes" "" "$(run "$dir/empty.jsonl" Bash "$push")"
check "a missing transcript passes" "" "$(run "$dir/none.jsonl" Bash "$push")"
check "the setting off passes" "" "$(OPT=false run "$dir/refused.jsonl" Bash "$push")"
check "the setting 0 passes" "" "$(OPT=0 run "$dir/refused.jsonl" Bash "$push")"
check "bad input passes" "" "$(echo nope | bash "$hook")"
exit $fail
