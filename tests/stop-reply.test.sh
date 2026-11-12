#!/usr/bin/env bash
# stop-reply.sh, sourced by the Stop hooks that read the agent's reply, lets
# the stop through (exit 0) when the transcript can't be read as JSON, and
# leaves only what the agent said since the user's last typed message.
set -u
lib="$(dirname "$0")/../plugins/vicky-skills/scripts/stop-reply.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
run() { jq -nc --arg t "$1" '{stop_hook_active:false,transcript_path:$t}' | bash -c '. "$1"; printf "%s" "$said"' _ "$lib"; }
printf 'not json\n' > "$dir/bad.jsonl"
run "$dir/bad.jsonl" >/dev/null 2>&1; code=$?
check "an unreadable transcript lets the stop through with exit 0" '[ $code = 0 ]'
{ jq -nc '{type:"assistant",message:{content:[{type:"text",text:"old reply"}]}}'
  jq -nc '{type:"user",message:{content:"next ask"}}'
  jq -nc '{type:"assistant",message:{content:[{type:"text",text:"new reply"}]}}'; } > "$dir/t.jsonl"
out=$(run "$dir/t.jsonl")
check "only the reply since the user's last message is read" 'grep -q "new reply" <<<"$out" && ! grep -q "old reply" <<<"$out"'
exit $fail
