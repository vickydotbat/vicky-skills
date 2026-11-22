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
# try <tool use id> <type> [session]: the hook's exit for a launch; a pass records it.
try() { jq -nc --arg i "$1" --arg s "$2" --arg t "$t" --arg sid "${3:-s1}" '{session_id:$sid,tool_use_id:$i,transcript_path:$t,tool_input:{subagent_type:$s,prompt:"p"}}' | bash "$guard" >/dev/null 2>"$tmp/err"; echo $?; }
o=vicky-skills:

# The snag: one script launched every batch, each launch resolved at once, and five ran against "at once: 2".
: > "$t"; batch 2
check "the first opponent of a batch of two starts" 0 "$(try r1 ${o}intent-opponent)"
check "the second starts" 0 "$(try r2 ${o}standards-opponent)"
receipt r1 A1 ${o}intent-opponent; receipt r2 A2 ${o}standards-opponent
check "a third, while the first two only hold launch receipts, is refused" 2 "$(try r3 ${o}simplicity-opponent)"
check "the refusal names each opponent still fighting" yes "$(grep -q 'intent-opponent' "$tmp/err" && grep -q 'standards-opponent' "$tmp/err" && echo yes || echo no)"
note A1 r1 "is waiting on its own background work"
check "an interim notification frees no slot" 2 "$(try r3 ${o}simplicity-opponent)"
note A1 r1 finished
check "a final notification frees one slot" 0 "$(try r3 ${o}simplicity-opponent)"
check "the slot it freed is taken" 2 "$(try r4 ${o}cause-opponent)"

# Launches in one burst land before any receipt is written: the hook's own record counts them.
: > "$t"; batch 3
check "burst one starts" 0 "$(try b1 ${o}intent-opponent s2)"
check "burst two starts" 0 "$(try b2 ${o}claims-opponent s2)"
check "burst three starts" 0 "$(try b3 ${o}cause-opponent s2)"
check "burst four is refused with no receipt in the transcript" 2 "$(try b4 ${o}standards-opponent s2)"
# Every launch of one script may reach the hook under one tool use id: each still counts.
: > "$t"; batch 2
try d1 ${o}intent-opponent s10 >/dev/null
check "a second launch under the same tool use id fills the batch" 0 "$(try d1 ${o}claims-opponent s10)"
check "a third under that id is refused" 2 "$(try d1 ${o}cause-opponent s10)"

# The record only bridges the gap until receipts land: a row older than 30 seconds holds no slot.
: > "$t"; batch 1
printf 'old1\t%sintent-opponent\t%s\n' "$o" "$(( $(date +%s) - 31 ))" > "$CLAUDE_PLUGIN_DATA/opponent-batch/s11.tsv"
check "a record row 31 seconds old holds no slot" 0 "$(try old2 ${o}claims-opponent s11)"
check "a fresh record row holds its slot" 2 "$(try old3 ${o}cause-opponent s11)"

# A launch both the record and the transcript hold counts once.
: > "$t"; batch 2
receipt k1 K1 ${o}intent-opponent; try k1 ${o}intent-opponent s12 >/dev/null
check "a launch in the record and the transcript counts once" 0 "$(try k2 ${o}claims-opponent s12)"
receipt k2 K2 ${o}claims-opponent
check "two receipts and two record rows fill a batch of two" 2 "$(try k3 ${o}cause-opponent s12)"
jq -nc '{type:"assistant",message:{content:[{type:"tool_use",id:"ts",name:"TaskStop",input:{task_id:"K1"}}]}}' >> "$t"
printf '' > "$CLAUDE_PLUGIN_DATA/opponent-batch/s12_.tsv"
check "an opponent stopped with TaskStop frees its slot" 0 "$(try k3 ${o}cause-opponent s12)"

# No batch.sh answer yet: three at a time, its ceiling.
: > "$t"
for i in 1 2 3; do try n$i ${o}intent-opponent s3 >/dev/null; done
check "with no batch.sh answer a fourth is refused" 2 "$(try n4 ${o}intent-opponent s3)"
note X n1 finished
check "a notification matched by tool use id frees a slot" 0 "$(try n4 ${o}intent-opponent s3)"

# Launches the transcript holds count before the hook has any record of them.
: > "$t"; batch 2
receipt p1 P1 ${o}intent-opponent; receipt p2 P2 ${o}claims-opponent
check "two receipts with no record of this session fill a batch of two" 2 "$(try p3 ${o}cause-opponent s7)"
note P1 other-id finished
check "a notification matched by its task id frees a slot" 0 "$(try p3 ${o}cause-opponent s7)"

# Concurrent hooks of one burst take turns, and a hook holds no lock after it ends.
: > "$t"; batch 3
for i in 1 2 3 4 5 6; do
  (jq -nc --arg i "c$i" --arg t "$t" '{session_id:"s8",tool_use_id:$i,transcript_path:$t,tool_input:{subagent_type:"vicky-skills:intent-opponent",prompt:"p"}}' \
    | bash "$guard" >/dev/null 2>"$tmp/c$i.err"; echo $? > "$tmp/c$i") &
done; wait
check "six launches at once pass three" 3 "$(cat "$tmp"/c[1-6] | grep -cx 0)"
# On a failure, each launch's exit and words show which path let it through.
[ "$(cat "$tmp"/c[1-6] | grep -cx 0)" = 3 ] || for i in 1 2 3 4 5 6; do echo "  c$i exit $(cat "$tmp/c$i"): $(cat "$tmp/c$i.err")"; done
try c7 general-purpose s8 >/dev/null; try c8 ${o}claims-opponent s8 >/dev/null; try c9 ${o}claims-opponent s8 >/dev/null
check "no lock is left behind" no "$( [ -e "$CLAUDE_PLUGIN_DATA/opponent-batch/s8_.lock" ] && echo yes || echo no)"

# An old launch the transcript holds and new ones only the record holds all count.
: > "$t"; batch 2
receipt u1 U1 ${o}intent-opponent
check "beside one receipted launch, one more starts" 0 "$(try u2 ${o}standards-opponent s13)"
check "and a third is refused" 2 "$(try u3 ${o}claims-opponent s13)"

# A launch in both counts once, and two launches under one id count twice.
: > "$t"; batch 2
receipt y1 Y1 ${o}intent-opponent; try y1 ${o}intent-opponent s16 >/dev/null
check "a launch the record and its receipt both hold leaves a slot of two" 0 "$(try y2 ${o}claims-opponent s16)"
: > "$t"; batch 2
receipt x1 X1 ${o}intent-opponent; try x1 ${o}intent-opponent s17 >/dev/null; try x1 ${o}intent-opponent s17 >/dev/null
check "two launches under one receipted id fill a batch of two" 2 "$(try x2 ${o}claims-opponent s17)"

# A quoted batch.sh answer above its ceiling raises nothing.
: > "$t"; batch 9
for i in 1 2 3; do try v$i ${o}intent-opponent s14 >/dev/null; done
check "an answer above the ceiling of three still refuses a fourth" 2 "$(try v4 ${o}intent-opponent s14)"
# A record it can't write refuses the launch.
: > "$t"; batch 3; touch "$CLAUDE_PLUGIN_DATA/opponent-batch/s15_.tsv"; chmod a-w "$CLAUDE_PLUGIN_DATA/opponent-batch/s15_.tsv"
check "a launch whose record it can't write is refused" 2 "$(try w1 ${o}intent-opponent s15)"
chmod u+w "$CLAUDE_PLUGIN_DATA/opponent-batch/s15_.tsv"

# A read that fails refuses the launch, never passes it uncounted.
mkdir -p "$tmp/badjq"; real=$(command -v jq)
printf '#!/usr/bin/env bash\ncase "$*" in *--rawfile*) exit 1;; esac\nexec %q "$@"\n' "$real" > "$tmp/badjq/jq"; chmod +x "$tmp/badjq/jq"
: > "$t"; batch 3
check "a launch whose read of the running opponents fails is refused" 2 "$(PATH="$tmp/badjq:$PATH" try f1 ${o}intent-opponent s10)"
printf '#!/usr/bin/env bash\ncase "$*" in *session_id*) exit 1;; esac\nexec %q "$@"\n' "$real" > "$tmp/badjq/jq"
check "a launch whose read of its own fields fails is refused" 2 "$(jq -nc --arg t "$t" '{session_id:"s10",tool_use_id:"f2",transcript_path:$t,tool_input:{subagent_type:"vicky-skills:intent-opponent"}}' | PATH="$tmp/badjq:$PATH" bash "$guard" >/dev/null 2>&1; echo $?)"
check "a launch that names no session is refused" 2 "$(jq -nc --arg t "$t" '{tool_use_id:"f3",transcript_path:$t,tool_input:{subagent_type:"vicky-skills:intent-opponent"}}' | bash "$guard" >/dev/null 2>&1; echo $?)"

# A held lock refuses the launch, never runs it unlocked; a lock past the hook's timeout is cleared.
: > "$CLAUDE_PLUGIN_DATA/opponent-batch/s11_.lock"
check "a launch that can't take the lock is refused" 2 "$(try k1 ${o}intent-opponent s11)"
check "a fresh lock it could not take stays" yes "$([ -f "$CLAUDE_PLUGIN_DATA/opponent-batch/s11_.lock" ] && echo yes || echo no)"
touch -d '-1 minute' "$CLAUDE_PLUGIN_DATA/opponent-batch/s11_.lock"
check "a lock left by a killed hook refuses that launch" 2 "$(try k2 ${o}intent-opponent s11)"
check "and the next launch takes it" 0 "$(try k3 ${o}intent-opponent s11)"

# Holds fights alone.
: > "$t"; batch 3
try h0 ${o}claims-opponent s4 >/dev/null
check "Holds beside a running opponent is refused" 2 "$(try h1 ${o}holds-opponent s4)"
note Y h0 finished
check "Holds with nothing running starts" 0 "$(try h1 ${o}holds-opponent s4)"
check "an opponent beside a running Holds is refused" 2 "$(try h2 ${o}claims-opponent s4)"

# A message sent to a finished opponent sets it working again.
: > "$t"; batch 1
receipt m1 M1 ${o}intent-opponent; try m1 ${o}intent-opponent s5 >/dev/null; note M1 m1 finished
check "a finished opponent holds no slot" 0 "$(try m2 ${o}claims-opponent s5)"
note M2 m2 finished
jq -nc '{type:"assistant",message:{content:[{type:"tool_use",id:"sm",name:"SendMessage",input:{to:"M1",message:"again"}}]}}' >> "$t"
check "after a message to it, it holds its slot again" 2 "$(try m3 ${o}cause-opponent s5)"

# A launch that failed holds no slot.
: > "$t"; batch 1
try e1 ${o}intent-opponent s6 >/dev/null
jq -nc '{type:"user",message:{content:[{type:"tool_result",tool_use_id:"e1",is_error:true,content:"boom"}]}}' >> "$t"
check "a launch whose result is an error holds no slot" 0 "$(try e2 ${o}intent-opponent s6)"

# Passes and bad input.
check "an agent that is no opponent passes" 0 "$(try z1 general-purpose s4)"
check "a reviewer passes" 0 "$(try z2 ${o}code-reviewer s4)"
check "a data folder it cannot write passes" 0 "$(jq -nc '{session_id:"s9",tool_use_id:"q",tool_input:{subagent_type:"vicky-skills:claims-opponent"}}' | CLAUDE_PLUGIN_DATA=/proc/version/x bash "$guard" >/dev/null 2>&1; echo $?)"
check "bad input passes" 0 "$(echo 'not json' | bash "$guard" >/dev/null 2>&1; echo $?)"
check "a missing transcript counts only the hook's own record" 0 "$(jq -nc '{session_id:"s9",tool_use_id:"q",transcript_path:"/nonexistent",tool_input:{subagent_type:"vicky-skills:claims-opponent"}}' | bash "$guard" >/dev/null 2>&1; echo $?)"
check "without jq it passes" 0 "$(echo '{}' | PATH=/nonexistent "$(command -v bash)" "$guard" >/dev/null 2>&1; echo $?)"
exit $fail
