#!/usr/bin/env bash
# Approved examples for D4: a new behaviour no approved example names becomes
# one line in the repo's Ideas place, never a ticket. A line in docs/agents
# names the place; a repo with no line gets an Ideas section in the pull
# request body.
set -u
hook="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/no-v1.sh"
fx=$(mktemp -d); trap 'rm -rf "$fx"' EXIT
export CLAUDE_PLUGIN_OPTION_GUARD_NO_V1=true
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
mkdir -p "$fx/named/docs/agents" "$fx/plain"
printf '# Domain\n\nIdeas: the team wiki'"'"'s Ideas page\n' > "$fx/named/docs/agents/domain.md"
{ jq -nc '{type:"assistant",message:{content:[{type:"tool_use",name:"Skill",input:{skill:"vicky-skills:do"}}]}}'
  jq -nc '{type:"user",message:{content:"go"}}'
  jq -nc --arg t "Done. A retry on a dropped connection could be a later ticket." '{type:"assistant",message:{content:[{type:"text",text:$t}]}}'
} > "$fx/t.jsonl"
reason() { jq -nc --arg t "$fx/t.jsonl" '{stop_hook_active:false,transcript_path:$t}' | CLAUDE_PROJECT_DIR="$1" bash "$hook" | jq -r 'select(.decision == "block") | .reason'; }

# Given an agent building an effort finds a behaviour no approved example names
# When its reply offers that behaviour as a later ticket or a follow-up
# Then the reply is stopped, and the agent writes the idea as one line in the Ideas place and says where it went
check "E8 a new behaviour goes to the Ideas place the repo names" 'reason "$fx/named" | grep -q "one line in the Ideas place, the team wiki'"'"'s Ideas page, and say where it went"'
check "E8 a repo with no Ideas line gets an Ideas section in the pull request body" 'reason "$fx/plain" | grep -q "one line in the Ideas place, an Ideas section in the pull request body, and say where it went"'

exit $fail
