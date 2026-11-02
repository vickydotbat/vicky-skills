#!/usr/bin/env bash
# approved-spec: the gate examples, approved 2026-11-02. A gate is text the
# agent reads, so each check reads the skills that wait on the user and the
# one file that says how to wait.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills"
gates="$root/skills/GATES.md"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

# Given any skill that stops to wait on your answer, approval or merge
# When it asks
# Then it asks in the one gate form, a first line of "🚪 Waiting on you: <the one thing>" with a watch behind it, written down in one place that the skill points to
ok=1
for s in engineering/do engineering/warp engineering/gamma-shift engineering/make-it-so productivity/red-pen; do
  grep -q '\.\./\.\./GATES\.md' "$root/skills/$s/SKILL.md" || { echo "     $s does not point at GATES.md"; ok=0; }
done
# take-pick's steer, as an agent reads it when the hook stops a pick asked with no gate.
fx=$(mktemp -d); trap 'rm -rf "$fx"' EXIT
{ jq -nc '{type:"user",message:{content:"go"}}'; jq -nc '{type:"assistant",message:{content:[{type:"text",text:"My pick is A. Which one?"}]}}'; } > "$fx/t.jsonl"
jq -nc --arg t "$fx/t.jsonl" '{stop_hook_active:false,transcript_path:$t}' | CLAUDE_PLUGIN_OPTION_GUARD_TAKE_PICK=true bash "$root/scripts/take-pick.sh" |
  jq -r '.reason // empty' | grep -q 'skills/GATES.md' || { echo "     take-pick's steer does not point at GATES.md"; ok=0; }
check "every wait on you is a gate" '[ $ok = 1 ] && grep -qF "🚪 Waiting on you: <the one thing>" "$gates" && grep -q "watch.sh" "$gates" && [ "$(grep -rlF "🚪 Waiting on you: <the one thing>" "$root/skills" | wc -l)" = 1 ]'

# Given a gate that asks you something with no pick attached
# When the watch ends and you have not answered
# Then the agent parks the work with a Waits on: line and goes on with the rest
check "a gate with no pick ends parked, never guessed" 'grep -qi "no pick" "$gates" && grep -q "Waits on:" "$gates"'
exit $fail
