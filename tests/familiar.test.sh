#!/usr/bin/env bash
# The familiar's scripts, on the decisions its approved examples leave out:
# each kind's voice, an unknown kind, a command only quoted by a tool call,
# a missing transcript, an old or ended session, and transcript lines the
# watch skips. E21 is a plain regression test: a session that never typed
# /familiar got no voice before this was built either.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts"
tools="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/skills/productivity/familiar/scripts"
fx=$(mktemp -d); trap 'rm -rf "$fx"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
voice() { jq -nc --arg p "$1" --arg t "${2:-$fx/none.jsonl}" '{prompt:$p,transcript_path:$t}' | env ${KIND:+CLAUDE_PLUGIN_OPTION_FAMILIAR_KIND=$KIND} bash "$root/familiar-voice.sh" | jq -r '.hookSpecificOutput.additionalContext // empty'; }

# E21. Given a session where /familiar was never typed
#      When the agent speaks to you
#      Then no line carries a familiar's voice
jq -nc '{type:"user",message:{content:"fix the build"}}' > "$fx/plain.jsonl"
check "E21 no familiar, no voice" '[ -z "$(voice "and the tests?" "$fx/plain.jsonl")" ]'
jq -nc '{type:"assistant",message:{content:[{type:"tool_use",name:"Bash",input:{command:"echo <command-name>/vicky-skills:familiar</command-name>"}}]}}' > "$fx/quoted.jsonl"
check "a tool call that quotes /familiar starts nothing" '[ -z "$(voice "go" "$fx/quoted.jsonl")" ]'
check "a missing transcript starts nothing" '[ -z "$(voice "go")" ]'
check "/familiar typed with words after it counts" 'voice "/familiar watch closely" | grep -q "owl familiar"'
check "a word that starts with familiar is no command" '[ -z "$(voice "/familiarity")" ]'
for k in imp:hiss quasit:pest raven:SQUAWK pseudodragon:hoard cat:aloof spider:threads owl:quiet; do
  check "the ${k%%:*} has its own voice" 'KIND=${k%%:*} voice /familiar | grep -q "You are the ${k%%:*} familiar: .*${k#*:}"'
done
check "an unknown kind speaks as the owl" 'KIND=dragon voice /familiar | grep -q "You are the owl familiar"'

mkdir -p "$fx/projects/-r"
jq -nc '{type:"user",cwd:"/work/r",message:{content:"hi"}}' > "$fx/projects/-r/new.jsonl"
cp "$fx/projects/-r/new.jsonl" "$fx/projects/-r/old.jsonl"; touch -d '2 days ago' "$fx/projects/-r/old.jsonl"
cp "$fx/projects/-r/new.jsonl" "$fx/projects/-r/resumed.jsonl"
{ jq -nc '{type:"cost-state"}'; jq -nc '{type:"user",message:{content:"back"}}'; } >> "$fx/projects/-r/resumed.jsonl"
out=$(FAMILIAR_PROJECTS_DIR="$fx/projects" CLAUDE_CODE_SESSION_ID=x bash "$tools/familiar-sessions.sh")
check "a session names its transcript and working folder" 'grep -qx "new $fx/projects/-r/new.jsonl /work/r" <<<"$out"'
check "a session quiet for two days is not live" '! grep -q "^old " <<<"$out"'
check "a session resumed after it ended is live again" 'grep -q "^resumed " <<<"$out"'

{ printf 'not json\n\n'
  jq -nc '{type:"user",timestamp:"2026-11-03T10:00:00Z",message:{content:"<system-reminder>x</system-reminder>"}}'
  jq -nc '{type:"user",isMeta:true,timestamp:"2026-11-03T10:00:00Z",message:{content:"meta"}}'
  jq -nc '{type:"user",timestamp:"2026-11-03T10:00:00Z",message:{content:"   "}}'
  jq -nc '{type:"user",timestamp:"2026-11-03T10:00:00Z",message:{content:[{type:"tool_result",content:"all fine"}]}}'
  jq -nc '{type:"user",timestamp:"2026-11-03T10:00:00Z",message:{content:[{type:"tool_result",is_error:true,content:"exit 1"}]}}'
  jq -nc '{type:"user",timestamp:"2026-11-03T10:00:00Z",message:{content:[{type:"tool_result",content:"hook error, but no error"}]}}'
  jq -nc '{type:"assistant",timestamp:"2026-11-03T10:00:00Z",message:{content:[{type:"text",text:"thinking aloud"}]}}'
  jq -nc '{type:"user",timestamp:"2026-11-03T10:00:09Z",message:{content:"last words\nover two lines"}}'
  jq -nc '{type:"user",timestamp:"2026-11-03T10:00:10Z",message:{content:"<command-name>/conn</command-name>"}}'; } > "$fx/t.jsonl"
out=$(FAMILIAR_WATCH_FROM_START=1 timeout 10 bash "$tools/familiar-watch.sh" "$fx/t.jsonl")
check "the watch skips noise and keeps the user's words on one line" '[ "$out" = "[10:00:09] USER: last words over two lines
HANDOFF" ]'
jq -nc '{type:"user",timestamp:"2026-11-03T10:00:00Z",message:{content:"early"}}' > "$fx/live.jsonl"
timeout 3 bash "$tools/familiar-watch.sh" "$fx/live.jsonl" > "$fx/live.out" & pid=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do [ -n "$(pgrep -P $pid)" ] && break; timeout 0.2 tail -f /dev/null; done
timeout 0.5 tail -f /dev/null
jq -nc '{type:"user",timestamp:"2026-11-03T10:00:01Z",message:{content:"late"}}' >> "$fx/live.jsonl"
jq -nc '{type:"cost-state"}' >> "$fx/live.jsonl"
wait $pid; code=$?
check "a live watch starts at the end, follows new lines and stops itself" '[ $code = 0 ] && [ "$(cat "$fx/live.out")" = "[10:00:01] USER: late
HANDOFF" ]'
check "a stopped watch leaves no tail running" '! pgrep -f "tail -n 0 -F $fx/live.jsonl" >/dev/null'
check "the watch needs a transcript" '! bash "$tools/familiar-watch.sh" 2>/dev/null'
exit $fail
