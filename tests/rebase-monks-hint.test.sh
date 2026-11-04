#!/usr/bin/env bash
# rebase-monks-hint adds context after a rebase stops on a conflict with no
# history-monks start, and stays quiet otherwise.
set -u
hook="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/rebase-monks-hint.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
: > "$dir/none.jsonl"
jq -nc '{type:"assistant",message:{content:[{type:"tool_use",name:"Skill",input:{skill:"vicky-skills:history-monks"}}]}}' > "$dir/monks.jsonl"
fail=0
said() { jq -nc --arg c "$1" --arg o "$2" --arg t "${3:-$dir/none.jsonl}" '{tool_input:{command:$c},tool_response:{stdout:"",stderr:$o},transcript_path:$t}' |
  CLAUDE_PLUGIN_OPTION_GUARD_REBASE_MONKS_HINT=${OPT:-true} bash "$hook" > "$dir/out"; local c=$?
  [ "$c" = 0 ] || { echo "exit $c"; return; }; o=$(jq -r '.hookSpecificOutput.additionalContext // empty' < "$dir/out"); [ -z "$o" ] || grep -c history-monks <<<"$o"; }
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got '$3', want '$2'"; fail=1; fi; }
c='CONFLICT (content): Merge conflict in src/Log.cs'
check "a rebase conflict with no history-monks is hinted" 1 "$(said 'git rebase origin/main' "$c")"
check "a rebase --onto conflict is hinted" 1 "$(said 'git rebase --onto origin/main abc' "$c")"
check "could not apply counts as a conflict" 1 "$(said 'git -C x rebase main' 'error: could not apply 1234... fix')"
check "a conflict after history-monks started is quiet" "" "$(said 'git rebase origin/main' "$c" "$dir/monks.jsonl")"
check "a clean rebase is quiet" "" "$(said 'git rebase origin/main' 'Successfully rebased')"
check "a merge conflict outside a rebase is quiet" "" "$(said 'git merge main' "$c")"
check "a quoted rebase in another command is quiet" "" "$(said 'echo rebasing' "$c")"
check "the setting off is quiet" "" "$(OPT=false said 'git rebase origin/main' "$c")"
check "the setting 0 is quiet" "" "$(OPT=0 said 'git rebase origin/main' "$c")"
check "bad input is quiet" "" "$(echo nope | bash "$hook")"
exit $fail
