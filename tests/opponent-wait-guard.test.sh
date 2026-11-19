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
for c in 'sudo gh pr merge 5' 'env X=1 gh pr merge 5' 'FOO=1 gh pr merge 5' 'timeout 60 gh pr merge 5' '{ gh pr merge 5; }' '! gh pr merge 5' \
  'gh -R o/r pr merge 5' 'bash -c "gh pr merge 5"' "sh -c 'gh pr merge 5'" 'gh api -X PUT repos/o/r/pulls/5/merge' 'gh pr edit 5 --ready' \
  'tea pr m 5' 'tea pulls m 5' 'tea  pr  m 5' 'gh pr merge 5; gh pr ready 6 --undo' '/usr/bin/gh pr merge 5' '(gh pr ready 5)' \
  "echo 'foo -m \"' ; gh pr merge 5 ; echo '\"'" "echo \"x -t '\" ; gh pr merge 5 ; echo \"'\"" "ssh host -t 'gh pr merge 5'" \
  "git commit -m \$'x\\'' ; gh pr merge 1 ; echo \\'a" "gh pr \$'merge' 5" '$(command -v gh) pr merge 5' '"$(which gh)" pr merge 5' \
  "$(printf 'gh pr \\\n merge 5')" 'tea pull merge 5' 'gh pr -R o/r merge 5' "gh api graphql -f query='mutation{mergePullRequest(input:{}){clientMutationId}}'" \
  'git commit -m "$(gh pr merge 5)"'; do
  check "a merge in another shape is refused: $c" 2 "$(code "$c")"
done
note A1 "finished"
check "an opponent that finished lets the merge through" 0 "$(code 'gh pr merge 5 --squash')"
jq -nc '{type:"assistant",message:{content:[{type:"tool_use",id:"s1",name:"SendMessage",input:{to:"A1",message:"check one more file"}}]}}' >> "$t"
check "an opponent sent a message after it finished is working again" 2 "$(code 'gh pr merge 5 --squash')"
note A1 "finished"
check "its next finished notification lets the merge through" 0 "$(code 'gh pr merge 5 --squash')"
launch tu5 E1 vicky-skills:claims-opponent
check "a GraphQL auto-merge is refused" 2 "$(code "gh api graphql -f query='mutation{enablePullRequestAutoMerge(input:{}){clientMutationId}}'")"
check "a GraphQL ready mark is refused" 2 "$(code "gh api graphql -f query='mutation{markPullRequestReadyForReview(input:{}){clientMutationId}}'")"
note E1 "finished"
launch tu2 B1 general-purpose
check "another agent still working never holds the merge" 0 "$(code 'gh pr merge 5 --squash')"
launch tu3 C1 vicky-skills:holds-opponent
check "a ready mark taken back passes" 0 "$(code 'gh pr ready 5 --undo')"
check "another command passes" 0 "$(code 'gh pr view 5')"
check "words that name a pr merge without gh pass" 0 "$(code 'echo next: pr merge 5')"
check "another tool whose name ends in gh passes" 0 "$(code 'xgh pr merge 5')"
check "a call to the merge commit API passes" 0 "$(code 'gh api repos/o/r/pulls/5/merge_commit')"
check "a title that names a merge passes" 0 "$(code 'git commit -m "gh pr merge waits now"')"
check "a pull request comment that names a merge passes" 0 "$(code 'gh pr comment 5 -b "gh pr merge 5 is next"')"
check "a merge after a commit whose message names one is still refused" 2 "$(code 'git commit --message="gh pr merge" && gh pr merge 5')"
note C1 "failed"
check "an opponent that failed is done, and lets the merge through" 0 "$(code 'gh pr merge 5')"
check "no transcript passes" 0 "$(jq -nc '{tool_input:{command:"gh pr merge 5"}}' | bash "$guard" >/dev/null 2>&1; echo $?)"
check "bad input passes" 0 "$(echo nope | bash "$guard" >/dev/null 2>&1; echo $?)"
echo 'not json' >> "$t"; launch tu4 D1 vicky-skills:intent-opponent
check "a broken transcript line is skipped, and the rest still counts" 2 "$(code 'gh pr merge 5')"
exit $fail
