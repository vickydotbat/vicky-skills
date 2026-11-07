#!/usr/bin/env bash
# approved-spec: the idle-stop-guard silent-end examples, approved 2026-11-07
# on a drafts page. The guard runs on a transcript the way Claude Code writes
# one: a background notice is a user message whose origin kind is
# task-notification.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills"
hook="$root/scripts/idle-stop-guard.sh"
fx=$(mktemp -d); trap 'rm -rf "$fx"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
. "$(dirname "$0")/lib/skill-step.sh"; step() { skill_step "$1" "$2"; }
user() { jq -nc --arg t "$1" '{type:"user",message:{content:$t}}'; }
notice() { jq -nc '{type:"user",origin:{kind:"task-notification",producer:"session-task"},message:{content:"<task-notification>\n<task-id>b1</task-id>\n<summary>Monitor event</summary>\n</task-notification>"}}'; }
text() { jq -nc --arg t "$1" '{type:"assistant",message:{content:[{type:"text",text:$t}]}}'; }
tool() { jq -nc --arg n "$1" --argjson i "${2:-{\}}" '{type:"assistant",message:{content:[{type:"tool_use",name:$n,input:$i}]}}'; }
stop() { jq -nc --arg t "$fx/t.jsonl" '{stop_hook_active:false,transcript_path:$t}' | env -u CLAUDE_PLUGIN_OPTION_GUARD_IDLE_STOP bash "$hook" 2>/dev/null; }
blocked() { [ "$(stop | jq -r '.decision // empty' 2>/dev/null)" = block ]; }
passes() { local out; out=$(stop); [ $? = 0 ] && [ -z "$out" ]; }

# IG1
# Given a turn that began from a background notice, did some work and wrote no reply
# When the turn ends
# Then it ends and is not sent back
{ user "go"; notice; tool Read '{"file_path":"x"}'; } > "$fx/t.jsonl"
check "IG1 a turn woken by a background notice may end silent" 'passes'

# IG4
# Given a watch line that shows work going as asked
# When the agent ends that turn
# Then the skill says the silent end is allowed, because the idle-stop guard lets a turn woken by a notice end with no reply
check "IG4 the familiar skill names the silent case" 'step "$root/skills/productivity/familiar/SKILL.md" 3 | grep -q "idle-stop guard" && step "$root/skills/productivity/familiar/SKILL.md" 3 | grep -qi "woken by a notice"'
exit $fail
