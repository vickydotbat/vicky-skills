#!/usr/bin/env bash
# The idle stop guard sends back a turn that did work and ends with no gate,
# no done line and nothing running, and lets a reply-only turn, a gate line, a
# done line, AskUserQuestion, a background Agent, Bash or Monitor, a second
# stop, a missing transcript and the setting off through.
set -u
hook="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/idle-stop-guard.sh"
fx=$(mktemp -d); trap 'rm -rf "$fx"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
user() { jq -nc --arg t "$1" '{type:"user",message:{content:$t}}'; }
text() { jq -nc --arg t "$1" '{type:"assistant",message:{content:[{type:"text",text:$t}]}}'; }
sent() { jq -nc --arg t "$1" '{type:"assistant",message:{content:[{type:"tool_use",name:"SendUserMessage",input:{message:$t}}]}}'; }
tool() { jq -nc --arg n "$1" --argjson i "${2:-{\}}" '{type:"assistant",message:{content:[{type:"tool_use",name:$n,input:$i}]}}'; }
stop() { jq -nc --arg t "${TRANSCRIPT:-$fx/t.jsonl}" --argjson a "${2:-false}" '{stop_hook_active:$a,transcript_path:$t}' |
  env -u CLAUDE_PLUGIN_OPTION_GUARD_IDLE_STOP ${1:+CLAUDE_PLUGIN_OPTION_GUARD_IDLE_STOP=$1} bash "$hook" 2>/dev/null; }
blocked() { [ "$(stop "${1:-}" "${2:-false}" | jq -r '.decision // empty' 2>/dev/null)" = block ]; }
passes() { local out; out=$(stop "${1:-}" "${2:-false}"); [ $? = 0 ] && [ -z "$out" ]; }

# The snag: work, a checkpoint naming the next step, a recap, and a stop.
{ user "go"; tool Bash '{"command":"ls"}'; sent "Next, I'm filing the small stars."; text "Recap: ADR written."; } > "$fx/t.jsonl"
check "work that ends on a next step with no tool call is sent back" 'blocked'
check "the setting unset stays on" 'blocked'
check "the setting true is on" 'blocked true'
check "the setting false is off" 'passes false'
check "the setting 0 is off" 'passes 0'
check "a second stop in the same turn goes through" 'passes "" true'
check "a sent-back stop exits 0" 'stop >/dev/null; [ $? = 0 ]'
check "the steer names the next tool call and both lines" 'r=$(stop | jq -r .reason); grep -q "tool call" <<<"$r" && grep -q "🏁 Done:" <<<"$r" && grep -q "🚪 Waiting on you:" <<<"$r"'
check "a missing transcript goes through" 'TRANSCRIPT="$fx/none.jsonl" passes'
printf 'not json\n' > "$fx/bad.jsonl"
check "a broken transcript goes through" 'TRANSCRIPT="$fx/bad.jsonl" passes'

{ user "hi"; sent "Hello."; } > "$fx/t.jsonl"
check "a turn that only replied goes through" 'passes'
{ user "go"; tool Read '{"file_path":"x"}'; sent "🚪 Waiting on you: tick the page"; } > "$fx/t.jsonl"
check "a gate line goes through" 'passes'
{ user "go"; tool Read '{"file_path":"x"}'; text "  🏁 Done: the hook landed."; } > "$fx/t.jsonl"
check "a done line goes through, in chat text too" 'passes'
{ user "go"; tool Read '{"file_path":"x"}'; sent "🏁 Done: landed."; text "Recap after."; } > "$fx/t.jsonl"
check "only the last reply counts: a recap after the done line is sent back" 'blocked'
{ user "go"; tool Read '{"file_path":"x"}'; sent "Shipped. 🏁 Done: landed."; } > "$fx/t.jsonl"
check "a done line must open the reply" 'blocked'
for t in 'AskUserQuestion {}' 'Monitor {}' 'Agent {}' 'Bash {"command":"make","run_in_background":true}'; do
  { user "go"; tool Read '{"file_path":"x"}'; tool ${t%% *} "${t#* }"; sent "Waiting."; } > "$fx/t.jsonl"
  check "something that wakes the session goes through: ${t%% *}" 'passes'
done
{ user "go"; tool Bash '{"command":"make","run_in_background":false}'; sent "Ran it."; } > "$fx/t.jsonl"
check "a foreground Bash call is no background job" 'blocked'
{ user "go"; tool Bash '{"command":"ls"}'; sent "🏁 Done: x"; user "thanks"; sent "You're welcome."; } > "$fx/t.jsonl"
check "only the turn since the user's last message counts" 'passes'
# Boundaries of the silent end, approved with it on 2026-11-07 and already true
# before it: a reply with no gate or done line, and a silent turn after a typed
# message, are still sent back.
notice() { jq -nc '{type:"user",origin:{kind:"task-notification",producer:"session-task"},message:{content:"<task-notification>\n<task-id>b1</task-id>\n</task-notification>"}}'; }
{ user "go"; notice; tool Read '{"file_path":"x"}'; text "Looked at it, all fine."; } > "$fx/t.jsonl"
check "a reply with no gate or done line after a background notice is sent back" 'blocked'
{ user "go"; tool Read '{"file_path":"x"}'; } > "$fx/t.jsonl"
check "a silent turn after a typed message is sent back" 'blocked'
# The 2026-11-07 snag: a task started in an earlier turn still runs, so the
# session will wake, and the stop goes through until a notice ends that task.
res() { jq -nc --arg t "$1" '{type:"user",message:{content:[{type:"tool_result",tool_use_id:"t1",content:$t}]}}'; }
done_notice() { jq -nc --arg i "$1" '{type:"user",origin:{kind:"task-notification"},message:{content:("<task-notification>\n<task-id>"+$i+"</task-id>\n<tool-use-id>t1</tool-use-id>\n<status>completed</status>\n</task-notification>")}}'; }
for start in 'Async agent launched successfully.\nagentId: a1b2 (internal ID)' 'Command running in background with ID: b3c4. Output is being written' 'Monitor started (task d5e6, expires in 30m)'; do
  id=$(grep -oE 'agentId: [a-z0-9]+|ID: [a-z0-9]+|task [a-z0-9]+' <<<"$start" | grep -oE '[a-z0-9]+$')
  { user "go"; tool Agent '{}'; res "$start"; user "next"; tool Bash '{"command":"ls"}'; text "Still reading."; } > "$fx/t.jsonl"
  check "a task from an earlier turn still running lets the stop through: $id" 'passes'
  { user "go"; tool Agent '{}'; res "$start"; done_notice "$id"; user "next"; tool Bash '{"command":"ls"}'; text "Still reading."; } > "$fx/t.jsonl"
  check "once a notice ends that task, the stop is sent back: $id" 'blocked'
done
{ user "go"; tool Agent '{}'; res "agentId: a1b2"; res "agentId: f7f8"; done_notice a1b2; user "next"; tool Bash '{"command":"ls"}'; text "Still reading."; } > "$fx/t.jsonl"
check "one of two tasks still running lets the stop through" 'passes'
root="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills"
check "warp's Zero friction line says a side ask or report never ends the turn" 'grep -q "never ends the turn: the same response carries the next course step.s tool call" "$root/skills/engineering/warp/SKILL.md"'
check "the style says a named next step carries its tool call" 'grep -q "carries that step.s tool call in the same response" "$root/output-styles/dungeon-master.md"'
check "the style says finished work opens with the done line" 'grep -q "open with \`🏁 Done:\`" "$root/output-styles/dungeon-master.md"'
exit $fail
