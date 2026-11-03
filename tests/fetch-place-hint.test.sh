#!/usr/bin/env bash
# The fetch-place hint: a fetch or unpack into /tmp gets one line of context
# steering it to a lasting place; anything else, the setting off, and bad
# input pass silently. It never refuses.
set -u
hook="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/fetch-place-hint.sh"
unset CLAUDE_PLUGIN_OPTION_FETCH_PLACE_HINT
fail=0
run() { jq -nc --arg c "$1" '{tool_name:"Bash",tool_input:{command:$c}}' | bash "$hook"; }
hinted() { local out; out=$(run "$1"); [ $? = 0 ] && jq -e '.hookSpecificOutput.additionalContext | test("lasting place")' <<<"$out" >/dev/null; }
quiet() { local out; out=$(run "$1"); [ $? = 0 ] && [ -z "$out" ]; }
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
for c in "curl -L -o /tmp/x/parts.zip https://example.invalid/p" "wget -P /tmp/cache https://example.invalid/p" "git clone https://example.invalid/r /tmp/r" "make pull PULL_ARGS='part/**' WORKSPACE=/tmp/ws" "tar -xzf parts.tgz -C /tmp/parts" "unzip parts.zip -d /tmp/parts" "aws s3 cp s3://b/k /tmp/k" "rsync -a host:/data/ /tmp/data/" "git lfs pull --include x; cp -r . /tmp/y"; do
  check "a fetch into /tmp is hinted: $c" "hinted \"\$c\""
done
for c in "curl -o ~/.cache/proj/parts.zip https://example.invalid/p" "ls /tmp/x" "echo hi > /tmp/x/out" "grep curl /tmp/notes.txt" "make test" "git status"; do
  check "anything else passes quietly: $c" "quiet \"\$c\""
done
check "the setting off passes quietly" 'out=$(CLAUDE_PLUGIN_OPTION_FETCH_PLACE_HINT=false run "wget -P /tmp/c https://example.invalid/p"); [ $? = 0 ] && [ -z "$out" ]'
check "bad input passes quietly" 'out=$(echo "not json" | bash "$hook"); [ $? = 0 ] && [ -z "$out" ]'
exit $fail
