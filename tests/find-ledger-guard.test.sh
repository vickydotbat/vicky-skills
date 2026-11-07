#!/usr/bin/env bash
# The find ledger guard sends back a done reply while the ledger has an open
# line, and lets through: no ledger, no done line, a closed ledger, a second
# stop, the setting off, a missing transcript and an empty payload.
set -u
hook="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/find-ledger-guard.sh"
fx=$(mktemp -d); sid="flg-$$"; mkdir -p "/tmp/$sid"; trap 'rm -rf "$fx" "/tmp/$sid"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
reply() { jq -nc --arg t "$1" '{type:"assistant",message:{content:[{type:"text",text:$t}]}}'; }
run() { jq -nc --arg s "${SID:-$sid}" --arg t "${TR:-$fx/t.jsonl}" --argjson a "${2:-false}" '{session_id:$s,stop_hook_active:$a,transcript_path:$t}' |
  env -u CLAUDE_PLUGIN_OPTION_GUARD_FIND_LEDGER ${1:+CLAUDE_PLUGIN_OPTION_GUARD_FIND_LEDGER=$1} bash "$hook" 2>/dev/null; }
blocked() { [ "$(run "${1:-}" "${2:-false}" | jq -r '.decision // empty' 2>/dev/null)" = block ]; }
passes() { local o; o=$(run "${1:-}" "${2:-false}"); [ $? = 0 ] && [ -z "$o" ]; }
L="/tmp/$sid/over-to-you-ledger.md"
printf 'F1 | open | a\nF2 | fixed | abc\nF3 | open|b\n' > "$L"
reply "🏁 Done: finished." > "$fx/t.jsonl"
check "a done reply with open lines is sent back" 'blocked'
check "every open line is named" '[[ "$(run)" == *F1* && "$(run)" == *F3* && "$(run)" != *F2* ]]'
check "the setting true is on" 'blocked true'
check "the setting false is off" 'passes false'
check "the setting 0 is off" 'passes 0'
check "a second stop passes" 'passes "" true'
check "a missing transcript passes" 'TR=$fx/none.jsonl passes'
check "an unknown session has no ledger and passes" 'SID=nosuch-$$ passes'
check "an empty payload passes" 'echo "" | bash "$hook" >/dev/null 2>&1'
reply "🚪 Waiting on you: the page." > "$fx/t.jsonl"
check "a gate line with open lines passes" 'passes'
reply "Working on F1." > "$fx/t.jsonl"
check "a plain reply with open lines is held too" 'blocked'
tooluse() { jq -nc --arg n "$1" '{type:"assistant",message:{content:[{type:"text",text:"Waiting."},{type:"tool_use",name:$n,input:{}}]}}'; }
tooluse Monitor > "$fx/t.jsonl"
check "a turn that left a Monitor running passes" 'passes'
tooluse Agent > "$fx/t.jsonl"
check "a turn that left an Agent running passes" 'passes'
tooluse AskUserQuestion > "$fx/t.jsonl"
check "a question asked passes" 'passes'
jq -nc '{type:"assistant",message:{content:[{type:"tool_use",name:"Bash",input:{command:"x",run_in_background:true}}]}}' > "$fx/t.jsonl"
check "a background command left running passes" 'passes'
printf 'F1 | open | a\n' > "$L"
jq -nc --arg t "🏁 Done: finished." '{type:"assistant",message:{content:[{type:"tool_use",name:"SendUserMessage",input:{message:$t}}]}}' > "$fx/t.jsonl"
check "a done reply sent through SendUserMessage with an open line is sent back" 'blocked'
reply "🏁 Done: finished." > "$fx/t.jsonl"
printf 'F1 | fixed | a\nF2 | handed on | GAME-1\n' > "$L"
reply "🏁 Done: finished." > "$fx/t.jsonl"
check "a done reply with every line closed passes" 'passes'
printf 'F1 | opened later | a\n' > "$L"
check "a word that only starts with open is no open line" 'passes'
rm -f "$L"
reply "🏁 Done: finished." > "$fx/t.jsonl"
printf '1. [x] a\n2. [ ] b\n' > "/tmp/$sid/over-to-you-p.md"
check "a done reply with no ledger after a page with an unmarked item is held" 'blocked'
reply "Working." > "$fx/t.jsonl"
check "no ledger and no done line passes" 'passes'
reply "🏁 Done: finished." > "$fx/t.jsonl"
printf '1. [x] a\n2. [x] b\n' > "/tmp/$sid/over-to-you-p.md"
check "a page with every item marked passes" 'passes'
printf '1. [~] a\n' > "/tmp/$sid/over-to-you-p.md"
check "a changed item counts as unmarked" 'blocked'
printf '1. [-] a\n' > "/tmp/$sid/over-to-you-p.md"
check "a failed item counts as unmarked" 'blocked'
rm -f "/tmp/$sid/over-to-you-p.md"
check "no page and no ledger passes" 'passes'
printf 'F1 | no bug | identified\nF2 | no bug |\n' > "$L"
check "a no-bug line with no reason is held" 'blocked'
printf 'F1 | no bug | identified\n' > "$L"
check "a no-bug line with a reason passes" 'passes'
printf 'F1 | open | a\n' > "$L"
reply "🏁 Done: finished." > "$fx/t.jsonl"
check "a block exits 0, so Claude Code reads its decision" 'run >/dev/null; [ $? = 0 ]'
exit $fail
