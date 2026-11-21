#!/usr/bin/env bash
# opponent-batch-guard refuses a deathmatch opponent launch while as many
# opponents as batch.sh allows are still fighting, and any launch beside Holds.
# A launch from a script resolves with a launch receipt at once, so only a
# final task notification counts as the opponent's report.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
guard="$root/plugins/vicky-skills/scripts/opponent-batch-guard.sh"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
fail=0
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got $3, want $2"; fail=1; fi; }
t="$tmp/t.jsonl"; export CLAUDE_PLUGIN_DATA="$tmp/data"
# batch <n>: batch.sh's answer, as a shell result in the transcript.
batch() { jq -nc --arg c "at once: $1
memory cap: 2.0G" '{type:"user",message:{content:[{type:"tool_result",tool_use_id:"b",content:$c}]}}' >> "$t"; }
# receipt <tool use id> <agent id> <type>: the launch record a script's tools.Agent leaves.
receipt() {
  jq -nc --arg i "$1" --arg s "$3" '{type:"assistant",message:{model:"<synthetic>",content:[{type:"tool_use",id:$i,name:"Agent",input:{subagent_type:$s,prompt:"p"}}]}}' >> "$t"
  jq -nc --arg i "$1" --arg a "$2" '{type:"user",isVirtual:true,message:{content:[{type:"tool_result",tool_use_id:$i,content:""}]},toolUseResult:{isAsync:true,status:"async_launched",agentId:$a}}' >> "$t"
}
# note <agent id> <tool use id> <summary tail>: a task notification as the harness queues it.
note() {
  jq -nc --arg c "<task-notification>
<task-id>$1</task-id>
<tool-use-id>$2</tool-use-id>
<status>completed</status>
<summary>Agent \"x\" $3</summary>
</task-notification>" '{type:"queue-operation",operation:"enqueue",content:$c}' >> "$t"
}
# go <tool use id> <type> [session]: the hook's exit for a launch; a pass records it.
go() { jq -nc --arg i "$1" --arg s "$2" --arg t "$t" --arg sid "${3:-s1}" '{session_id:$sid,tool_use_id:$i,transcript_path:$t,tool_input:{subagent_type:$s,prompt:"p"}}' | bash "$guard" >/dev/null 2>"$tmp/err"; echo $?; }
o=vicky-skills:

# The snag: one script launched every batch, each launch resolved at once, and five ran against "at once: 2".
: > "$t"; batch 2
check "the first opponent of a batch of two starts" 0 "$(go r1 ${o}intent-opponent)"
check "the second starts" 0 "$(go r2 ${o}standards-opponent)"
receipt r1 A1 ${o}intent-opponent; receipt r2 A2 ${o}standards-opponent
check "a third, while the first two only hold launch receipts, is refused" 2 "$(go r3 ${o}simplicity-opponent)"
check "the refusal says a launch receipt is no report" yes "$(grep -q 'launch receipt' "$tmp/err" && grep -q 'task notification' "$tmp/err" && echo yes || echo no)"
check "the refusal names the limit" yes "$(grep -q '2 at a time' "$tmp/err" && echo yes || echo no)"
check "the refusal names the opponents still fighting" yes "$(grep -q 'intent-opponent, standards-opponent still fight' "$tmp/err" && echo yes || echo no)"
note A1 r1 "is waiting on its own background work"
check "an interim notification frees no slot" 2 "$(go r3 ${o}simplicity-opponent)"
note A1 r1 finished
check "a final notification frees one slot" 0 "$(go r3 ${o}simplicity-opponent)"
check "the slot it freed is taken" 2 "$(go r4 ${o}cause-opponent)"

# Launches in one burst land before any receipt is written: the hook's own record counts them.
: > "$t"; batch 3
check "burst one starts" 0 "$(go b1 ${o}intent-opponent s2)"
check "burst two starts" 0 "$(go b2 ${o}claims-opponent s2)"
check "burst three starts" 0 "$(go b3 ${o}cause-opponent s2)"
check "burst four is refused with no receipt in the transcript" 2 "$(go b4 ${o}standards-opponent s2)"
check "a hook rerun for a launch it passed passes again" 0 "$(go b1 ${o}intent-opponent s2)"

# No batch.sh answer yet: three at a time, its ceiling.
: > "$t"
for i in 1 2 3; do go n$i ${o}intent-opponent s3 >/dev/null; done
check "with no batch.sh answer a fourth is refused" 2 "$(go n4 ${o}intent-opponent s3)"
note X n1 finished
check "a notification matched by tool use id frees a slot" 0 "$(go n4 ${o}intent-opponent s3)"

# Launches the transcript holds count before the hook has any record of them.
: > "$t"; batch 2
receipt p1 P1 ${o}intent-opponent; receipt p2 P2 ${o}claims-opponent
check "two receipts with no record of this session fill a batch of two" 2 "$(go p3 ${o}cause-opponent s7)"
note P1 other-id finished
check "a notification matched by its task id frees a slot" 0 "$(go p3 ${o}cause-opponent s7)"

# Concurrent hooks of one burst take turns, and a hook holds no lock after it ends.
: > "$t"; batch 3
for i in 1 2 3 4 5 6; do go c$i ${o}intent-opponent s8 > "$tmp/c$i" & done; wait
check "six launches at once pass three" 3 "$(cat "$tmp"/c[1-6] | grep -cx 0)"
start=$(date +%s%N); go c7 general-purpose s8 >/dev/null; go c8 ${o}claims-opponent s8 >/dev/null; go c9 ${o}claims-opponent s8 >/dev/null
check "two launches in a row each take the lock at once" yes "$( [ $(( ($(date +%s%N) - start) / 1000000 )) -lt 1500 ] && echo yes || echo no)"
check "no lock is left behind" no "$( [ -e "$CLAUDE_PLUGIN_DATA/opponent-batch/s8.lock" ] && echo yes || echo no)"

# Holds fights alone.
: > "$t"; batch 3
go h0 ${o}claims-opponent s4 >/dev/null
check "Holds beside a running opponent is refused" 2 "$(go h1 ${o}holds-opponent s4)"
check "the refusal says Holds fights alone" yes "$(grep -q alone "$tmp/err" && echo yes || echo no)"
note Y h0 finished
check "Holds with nothing running starts" 0 "$(go h1 ${o}holds-opponent s4)"
check "an opponent beside a running Holds is refused" 2 "$(go h2 ${o}claims-opponent s4)"

# A message sent to a finished opponent sets it working again.
: > "$t"; batch 1
receipt m1 M1 ${o}intent-opponent; go m1 ${o}intent-opponent s5 >/dev/null; note M1 m1 finished
check "a finished opponent holds no slot" 0 "$(go m2 ${o}claims-opponent s5)"
note M2 m2 finished
jq -nc '{type:"assistant",message:{content:[{type:"tool_use",id:"sm",name:"SendMessage",input:{to:"M1",message:"again"}}]}}' >> "$t"
check "after a message to it, it holds its slot again" 2 "$(go m3 ${o}cause-opponent s5)"

# A launch that failed holds no slot.
: > "$t"; batch 1
go e1 ${o}intent-opponent s6 >/dev/null
jq -nc '{type:"user",message:{content:[{type:"tool_result",tool_use_id:"e1",is_error:true,content:"boom"}]}}' >> "$t"
check "a launch whose result is an error holds no slot" 0 "$(go e2 ${o}intent-opponent s6)"

# Passes and bad input.
check "an agent that is no opponent passes" 0 "$(go z1 general-purpose s4)"
check "a reviewer passes" 0 "$(go z2 ${o}code-reviewer s4)"
check "a data folder it cannot write passes" 0 "$(jq -nc '{session_id:"s9",tool_use_id:"q",tool_input:{subagent_type:"vicky-skills:claims-opponent"}}' | CLAUDE_PLUGIN_DATA=/proc/version/x bash "$guard" >/dev/null 2>&1; echo $?)"
check "bad input passes" 0 "$(echo 'not json' | bash "$guard" >/dev/null 2>&1; echo $?)"
check "a missing transcript counts only the hook's own record" 0 "$(jq -nc '{session_id:"s9",tool_use_id:"q",transcript_path:"/nonexistent",tool_input:{subagent_type:"vicky-skills:claims-opponent"}}' | bash "$guard" >/dev/null 2>&1; echo $?)"
check "without jq it passes" 0 "$(echo '{}' | PATH=/nonexistent "$(command -v bash)" "$guard" >/dev/null 2>&1; echo $?)"
exit $fail
