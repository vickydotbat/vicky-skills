#!/usr/bin/env bash
# opponent-wait-guard refuses a ready mark or a merge while a deathmatch
# opponent this session launched has not sent its final notification.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
guard="$root/plugins/vicky-skills/scripts/opponent-wait-guard.sh"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
fail=0
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got $3, want $2"; fail=1; fi; }
t="$tmp/t.jsonl"
# launch <tool use id> <agent id> <type>: an async Agent call and its result, as the transcript holds them.
launch() {
  jq -nc --arg i "$1" --arg s "$3" '{type:"assistant",message:{content:[{type:"tool_use",id:$i,name:"Agent",input:{subagent_type:$s,prompt:"p"}}]}}' >> "$t"
  jq -nc --arg i "$1" --arg a "$2" '{type:"user",message:{content:[{type:"tool_result",tool_use_id:$i,content:[{type:"text",text:"launched"}]}]},toolUseResult:{agentId:$a,status:"async_launched",isAsync:true}}' >> "$t"
}
# note <agent id> <summary tail>: a task notification, queued as the harness queues it.
note() {
  jq -nc --arg c "<task-notification>
<task-id>$1</task-id>
<status>completed</status>
<summary>Agent \"x\" $2</summary>
</task-notification>" '{type:"queue-operation",operation:"enqueue",content:$c}' >> "$t"
}
code() { jq -nc --arg c "$1" --arg t "$t" '{tool_input:{command:$c},transcript_path:$t}' | bash "$guard" >/dev/null 2>&1; echo $?; }

: > "$t"; launch tu1 A1 vicky-skills:claims-opponent
check "a merge while an opponent never reported is refused" 2 "$(code 'gh pr merge 5 --squash')"
check "a ready mark while an opponent never reported is refused" 2 "$(code 'gh pr ready 5')"
note A1 "is waiting on its own background work"
check "an opponent waiting on its own background work still holds the merge" 2 "$(code 'gh pr merge 5 --squash')"
msg=$(jq -nc --arg c 'gh pr merge 5' --arg t "$t" '{tool_input:{command:$c},transcript_path:$t}' | bash "$guard" 2>&1 >/dev/null)
check "the refusal names the agent and what to wait for" yes "$(grep -q A1 <<<"$msg" && grep -q finished <<<"$msg" && echo yes || echo no)"
check "a Gitea merge is refused too" 2 "$(code 'tea pr merge 5 </dev/null')"
check "a merge behind a cd is refused" 2 "$(code 'cd repo && gh pr merge 5 --squash')"
note A1 "finished"
check "an opponent that finished lets the merge through" 0 "$(code 'gh pr merge 5 --squash')"
launch tu2 B1 general-purpose
check "another agent still working never holds the merge" 0 "$(code 'gh pr merge 5 --squash')"
launch tu3 C1 vicky-skills:holds-opponent
check "a ready mark taken back passes" 0 "$(code 'gh pr ready 5 --undo')"
check "another command passes" 0 "$(code 'gh pr view 5')"
check "a title that names a merge passes" 0 "$(code 'git commit -m "gh pr merge waits now"')"
note C1 "failed"
check "an opponent that failed is done, and lets the merge through" 0 "$(code 'gh pr merge 5')"
check "no transcript passes" 0 "$(jq -nc '{tool_input:{command:"gh pr merge 5"}}' | bash "$guard" >/dev/null 2>&1; echo $?)"
check "bad input passes" 0 "$(echo nope | bash "$guard" >/dev/null 2>&1; echo $?)"
echo 'not json' >> "$t"; launch tu4 D1 vicky-skills:intent-opponent
check "a broken transcript line is skipped, and the rest still counts" 2 "$(code 'gh pr merge 5')"
exit $fail
