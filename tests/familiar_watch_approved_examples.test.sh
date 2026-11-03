#!/usr/bin/env bash
# Approved examples for S1 and E14, E15 and E26: the familiar's watch script
# follows a session transcript and prints one line per event it acts on.
set -u
watch="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/skills/productivity/familiar/scripts/familiar-watch.sh"
fx=$(mktemp -d); trap 'rm -rf "$fx"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
long=$(printf 'x%.0s' $(seq 1 600))
typed() { jq -nc --arg t "$1" '{type:"user",timestamp:"2026-11-03T16:05:01.000Z",message:{content:$t}}'; }
sent() { jq -nc --arg t "$1" '{type:"assistant",timestamp:"2026-11-03T16:05:02.000Z",message:{content:[{type:"tool_use",name:"SendUserMessage",input:{message:$t}}]}}'; }
refused() { jq -nc --arg t "$1" '{type:"user",timestamp:"2026-11-03T16:05:03.000Z",message:{content:[{type:"tool_result",is_error:true,content:$t}]}}'; }
midturn() { jq -nc --arg t "$1" '{type:"user",timestamp:"2026-11-03T16:05:04.000Z",message:{content:[{type:"tool_result",content:("ok\n\nThe user sent a new message while you were working:\n" + $t + "\n\nThis is how Claude Code surfaces messages")}]}}'; }
compacted() { jq -nc '{type:"system",subtype:"compact_boundary",timestamp:"2026-11-03T16:05:05.000Z"}'
  jq -nc '{type:"user",isCompactSummary:true,timestamp:"2026-11-03T16:05:05.000Z",message:{content:"This session is being continued from a previous conversation. Summary: secret plans"}}'; }
ended() { jq -nc '{type:"cost-state",sessionId:"s1"}'; }
# Runs the watch over a finished transcript, from its first line, with a guard timeout.
run() { FAMILIAR_WATCH_FROM_START=1 timeout 10 bash "$watch" "$fx/t.jsonl" ${1:+"$1"}; }

# Given the watch runs on a live session
# When the user types a message there
# Then the watch prints one line: the time, USER, and the first 400 characters
{ typed "Hello $long"; ended; } > "$fx/t.jsonl"
out=$(run)
check "S1 her message is one USER line, cut at 400 characters" '[ "$(grep -c USER <<<"$out")" = 1 ] && grep -qx "\[16:05:01\] USER: Hello ${long:0:394}" <<<"$out"'

# Given the watch runs on a live session
# When the agent sends the user a message, or a hook refuses a tool call
# Then the watch prints one line, AGENT or REFUSED, with the time and the first 400 characters
{ sent "Done $long"; refused "PreToolUse:Bash hook error: refused $long"; ended; } > "$fx/t.jsonl"
out=$(run)
check "S1 an agent reply is one AGENT line" 'grep -qx "\[16:05:02\] AGENT: Done ${long:0:395}" <<<"$out"'
check "S1 a refusal is one REFUSED line" 'grep -q "^\[16:05:03\] REFUSED: PreToolUse:Bash hook error: refused x" <<<"$out" && [ "$(grep REFUSED <<<"$out" | wc -c)" -le 425 ]'

# Given the watch runs on a live session
# When the user types /conn there, or the session ends
# Then the watch prints HANDOFF and stops
{ typed "<command-name>/vicky-skills:conn</command-name>"; typed "after the handoff"; } > "$fx/t.jsonl"
out=$(run); code=$?
check "S1 a typed /conn prints HANDOFF and stops" '[ $code = 0 ] && [ "$(tail -n 1 <<<"$out")" = HANDOFF ] && ! grep -q "after the handoff" <<<"$out"'
{ typed "bye"; ended; } > "$fx/t.jsonl"
out=$(run); code=$?
check "S1 the session's end prints HANDOFF and stops" '[ $code = 0 ] && [ "$(tail -n 1 <<<"$out")" = HANDOFF ]'

# Given the watch runs on a live session
# When that session compacts its context
# Then the watch prints one COMPACTED line with the time, and none of the summary text
{ compacted; ended; } > "$fx/t.jsonl"
out=$(run)
check "E14 a compaction is one COMPACTED line" 'grep -qx "\[16:05:05\] COMPACTED" <<<"$out" && ! grep -q "secret plans" <<<"$out" && ! grep -q USER <<<"$out"'

# Given the watch runs on a live session
# When you send a message while its agent is working
# Then the watch prints one USER line, the same as for a typed message
{ midturn "stop, wrong repo"; ended; } > "$fx/t.jsonl"
out=$(run)
check "E15 a message sent mid-turn is one USER line" 'grep -qx "\[16:05:04\] USER: stop, wrong repo" <<<"$out"'

# Given three other sessions are live
# When you type /familiar
# Then each gets its own watch and debt note, and every line names its session
{ typed "hi"; ended; } > "$fx/t.jsonl"
out=$(run vicky-skills-4f)
check "E26 every line names its session" 'grep -qx "\[16:05:01\] vicky-skills-4f USER: hi" <<<"$out" && grep -qx "vicky-skills-4f HANDOFF" <<<"$out"'

exit $fail
