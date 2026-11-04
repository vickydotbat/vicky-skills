#!/usr/bin/env bash
# publish-guard refuses making a repository public unless the user's last
# message says public, and lets other commands, bad input and the setting off through.
set -u
hook="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/publish-guard.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
fail=0
user() { jq -nc --arg t "$1" '{type:"user",message:{content:$t}}' > "$dir/t.jsonl"; }
run() { jq -nc --arg c "$1" --arg t "$dir/t.jsonl" '{tool_input:{command:$c},transcript_path:$t}' |
  CLAUDE_PLUGIN_OPTION_GUARD_PUBLISH=${OPT:-true} bash "$hook" > "$dir/out"; local c=$?
  [ "$c" = 0 ] || { echo "exit $c"; return; }; jq -r '.hookSpecificOutput.permissionDecision // empty' < "$dir/out"; }
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got '$3', want '$2'"; fail=1; fi; }
user "set up branch protections and get it merged"
for c in "gh repo edit o/r --visibility public --accept-visibility-change-consequences" "gh repo create o/r --public" \
  "gh api -X PATCH repos/o/r -f private=false" "gh api -X PATCH repos/o/r -f visibility=public" "tea repo edit --private=false"; do
  check "refused with no say-so: $c" deny "$(run "$c")"
done
check "the refusal says to ask" 1 "$(run 'gh repo create o/r --public' >/dev/null; grep -c 'Ask the user' "$dir/out")"
user "yes, make it public"
check "the user's own say-so lets it through" "" "$(run 'gh repo edit o/r --visibility public')"
jq -nc '{type:"user",message:{content:"make it public"}}' > "$dir/t.jsonl"; jq -nc '{type:"user",isMeta:true,message:{content:[{type:"text",text:"skill text"}]}}' >> "$dir/t.jsonl"
check "injected skill text is not the user's last message" "" "$(run 'gh repo edit o/r --visibility public')"
user "make it private again"
check "a private change passes" "" "$(run 'gh repo edit o/r --visibility private')"
check "an unrelated gh call passes" "" "$(run 'gh repo view o/r')"
check "a quoted mention in a commit passes" "" "$(run 'git commit -m done')"
user "go"
check "the setting off passes" "" "$(OPT=false run 'gh repo create o/r --public')"
check "the setting 0 passes" "" "$(OPT=0 run 'gh repo create o/r --public')"
check "bad input passes" "" "$(echo nope | bash "$hook")"
exit $fail
