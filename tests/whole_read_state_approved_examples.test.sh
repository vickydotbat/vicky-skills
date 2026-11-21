#!/usr/bin/env bash
# approved-spec: the examples approved on the note "LC-6 whole-read-guard
# decides from state". The guard reads the session transcript for an earlier
# whole read of the same ticket. Its example "the session transcript can't be
# read" holds already, so it lives in whole-read-guard.test.sh as a plain
# regression test.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
scripts="$root/plugins/vicky-skills/scripts"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
guard="$scripts/whole-read-guard.sh"
fx=$(mktemp -d); trap 'rm -rf "$fx"' EXIT
git -C "$fx" init -q && mkdir -p "$fx/docs/agents"
printf '| Operation | How |\n| --- | --- |\n| Read, whole | `tracker view --comments <id>` |\n' >"$fx/docs/agents/issue-tracker.md"
bashcall() { jq -nc --arg c "$1" '{type:"assistant",message:{content:[{type:"tool_use",name:"Bash",input:{command:$c}}]}}'; }
run() { jq -nc --arg c "$1" --arg d "$fx" --arg t "${2:-$fx/t.jsonl}" '{tool_name:"Bash",tool_input:{command:$c},cwd:$d,transcript_path:$t}' | bash "$guard" 2>&1 >/dev/null; echo "exit=$?"; }

# Given the agent read ticket 42 whole with read-item.sh this session
# When it later reads ticket 42 piped through head
# Then the read goes through
bashcall "read-item.sh 42" >"$fx/t.jsonl"
check "LC-6 E1 a ticket read whole before may be cut" 'run "read-item.sh 42 | head -20" | grep -qx "exit=0"'

# Given a whole read of ticket 42 this session
# When the agent reads ticket 43 piped through head
# Then it is refused, with a steer to run read-item.sh 43
check "LC-6 E3 another ticket's cut read is refused" 'out=$(run "read-item.sh 43 | head"); grep -q "exit=2" <<<"$out" && grep -q "read-item.sh 43" <<<"$out"'

# Given no whole read of ticket 42 this session
# When the agent saves ticket 42 to a file and greps the file
# Then the agent reads a steer to run read-item.sh 42 first
: >"$fx/t.jsonl"
check "LC-6 E2 saving then grepping an unread ticket gets the steer" 'run "read-item.sh 42 > t42.txt; grep Decision t42.txt" | grep -q "read-item.sh 42"'

# Given the repo's own "Read, whole" command read ticket 42 whole this session
# When the agent reads ticket 42 through sed -n
# Then the read goes through
bashcall "tracker view --comments 42" >"$fx/t.jsonl"
check "LC-6 E5 the repo's own whole read counts" 'run "tracker view --comments 42 | sed -n 1,9p" | grep -qx "exit=0"'

exit $fail
