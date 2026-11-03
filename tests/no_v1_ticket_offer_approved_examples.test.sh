#!/usr/bin/env bash
# approved-spec: the never-a-V1 Ideas line example, approved 2026-11-03 on the
# captain's log ticket. The hook runs on a fixture transcript of a building
# session, as the session's own stop would.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
hook="$root/plugins/vicky-skills/scripts/no-v1.sh"
fx=$(mktemp -d); trap 'rm -rf "$fx"' EXIT
export CLAUDE_PLUGIN_OPTION_GUARD_NO_V1=true
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
reply() {
  jq -nc '{type:"assistant",message:{role:"assistant",content:[{type:"tool_use",name:"Skill",input:{skill:"vicky-skills:do"}}]}}' > "$fx/t.jsonl"
  jq -nc '{type:"user",message:{role:"user",content:"build the export"}}' >> "$fx/t.jsonl"
  jq -nc --arg r "$1" '{type:"assistant",message:{role:"assistant",content:[{type:"text",text:$r}]}}' >> "$fx/t.jsonl"
}
stop() { jq -nc --arg t "$fx/t.jsonl" '{hook_event_name:"Stop",stop_hook_active:false,transcript_path:$t}' | CLAUDE_PROJECT_DIR="$fx" bash "$hook" 2>/dev/null; }

# Given an agent that found a new behaviour no approved example names
# When its reply offers to file that behaviour as a ticket of its own
# Then the reply is stopped, and the agent writes the idea as one line under Ideas in the pull request body instead
ok=1
for r in "The export works. Exporting to JSON would be nice too, so I can file that as a ticket of its own." "Done. I'll open a new ticket for exporting to JSON." "Shipped. Should I file a ticket for a JSON export?"; do
  reply "$r"; stop | jq -e '.decision == "block" and (.reason | test("one line in the Ideas place, an Ideas section in the pull request body"))' >/dev/null 2>&1 || { ok=0; echo "     not stopped: $r"; }
done
check "a new behaviour becomes an Ideas line, not a ticket" '[ $ok = 1 ]'
exit $fail
