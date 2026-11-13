#!/usr/bin/env bash
# The familiar's scripts, on the decisions its approved examples leave out:
# each kind's voice, an unknown kind, a later turn in a familiar session,
# an old or ended session, and transcript lines the watch skips. E21 is a plain
# regression test: a session that never typed /familiar gets no voice.
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
jq -nc '{type:"user",message:{content:"<command-name>/vicky-skills:familiar</command-name>"}}' > "$fx/started.jsonl"
check "a later turn in a familiar session gets no second copy of the voice" '[ -z "$(voice "and now?" "$fx/started.jsonl")" ]'
check "/familiar typed with words after it counts" 'voice "/familiar watch closely" | grep -q "owl familiar"'
check "a word that starts with familiar is no command" '[ -z "$(voice "/familiarity")" ]'
for k in imp:hiss quasit:pest raven:croak parrot:SQUAWK pseudodragon:hoard cat:aloof spider:threads owl:quiet; do
  check "the ${k%%:*} has its own voice" 'KIND=${k%%:*} voice /familiar | grep -q "You are the ${k%%:*} familiar: .*${k#*:}"'
done
check "an unknown kind speaks as the owl" 'KIND=dragon voice /familiar | grep -q "You are the owl familiar"'

mkdir -p "$fx/projects/-r"
jq -nc '{type:"user",cwd:"/work/r",message:{content:"hi"}}' > "$fx/projects/-r/new.jsonl"
cp "$fx/projects/-r/new.jsonl" "$fx/projects/-r/old.jsonl"; touch -d '2 days ago' "$fx/projects/-r/old.jsonl"
cp "$fx/projects/-r/new.jsonl" "$fx/projects/-r/resumed.jsonl"
{ jq -nc '{type:"cost-state"}'; jq -nc '{type:"user",message:{content:"back"}}'; } >> "$fx/projects/-r/resumed.jsonl"
out=$(FAMILIAR_SESSIONS_DIR="$fx/no-records" FAMILIAR_PROJECTS_DIR="$fx/projects" CLAUDE_CODE_SESSION_ID=x bash "$tools/familiar-sessions.sh"); code=$?
check "the session list exits 0" '[ $code = 0 ]'
check "a session names its transcript and working folder" 'grep -qx "new $fx/projects/-r/new.jsonl /work/r" <<<"$out"'
check "a session quiet for two days is not live" '! grep -q "^old " <<<"$out"'
check "a session resumed after it ended is live again" 'grep -q "^resumed " <<<"$out"'
# Claude Code keeps a record per running session, naming its process. Where
# those records exist, a session whose process has ended is not live.
mkdir -p "$fx/records"; dead=$(bash -c 'echo $$')
jq -nc --argjson p $$ '{pid:$p, sessionId:"new"}' > "$fx/records/1.json"
jq -nc --argjson p "$dead" '{pid:$p, sessionId:"resumed"}' > "$fx/records/2.json"
out=$(FAMILIAR_SESSIONS_DIR="$fx/records" FAMILIAR_PROJECTS_DIR="$fx/projects" CLAUDE_CODE_SESSION_ID=x bash "$tools/familiar-sessions.sh")
check "a session whose process runs is live" 'grep -q "^new " <<<"$out"'
check "a session whose process ended is not live" '! grep -q "^resumed " <<<"$out"'

{ printf 'not json\n\n'
  jq -nc '{type:"user",timestamp:"2026-11-03T10:00:00Z",message:{content:"<system-reminder>x</system-reminder>"}}'
  jq -nc '{type:"user",isMeta:true,timestamp:"2026-11-03T10:00:00Z",message:{content:"meta"}}'
  jq -nc '{type:"user",timestamp:"2026-11-03T10:00:00Z",message:{content:"   "}}'
  jq -nc '{type:"user",timestamp:"2026-11-03T10:00:00Z",message:{content:[{type:"tool_result",content:"all fine"}]}}'
  jq -nc '{type:"user",timestamp:"2026-11-03T10:00:00Z",message:{content:[{type:"tool_result",is_error:true,content:"exit 1"}]}}'
  jq -nc '{type:"user",timestamp:"2026-11-03T10:00:00Z",message:{content:[{type:"tool_result",content:"hook error, but no error"}]}}'
  jq -nc '{type:"user",timestamp:"2026-11-03T10:00:00Z",message:{content:[{type:"tool_result",is_error:true,content:"Exit code 1\nassert x, \"the request was refused\""}]}}'
  jq -nc '{type:"user",timestamp:"2026-11-03T10:00:00Z",message:{content:"<bash-stdout>[main ed1259a] done</bash-stdout><bash-stderr></bash-stderr>"}}'
  jq -nc '{type:"assistant",timestamp:"2026-11-03T10:00:00Z",message:{content:[{type:"text",text:"thinking aloud"}]}}'
  jq -nc '{type:"user",timestamp:"2026-11-03T10:00:09Z",message:{content:"last words\nover two lines"}}'
  jq -nc '{type:"user",timestamp:"2026-11-03T10:00:10Z",message:{content:"<command-name>/conn</command-name>"}}'; } > "$fx/t.jsonl"
out=$(FAMILIAR_WATCH_FROM_START=1 timeout 10 bash "$tools/familiar-watch.sh" "$fx/t.jsonl")
check "the watch skips noise and keeps the user's words on one line" '[ "$out" = "[10:00:09] USER: last words over two lines
HANDOFF" ]'
jq -nc '{type:"user",timestamp:"2026-11-03T10:00:00Z",message:{content:"early"}}' > "$fx/live.jsonl"
# The cap only stops a hung watch; the loop below waits for its tail to start.
timeout 20 bash "$tools/familiar-watch.sh" "$fx/live.jsonl" > "$fx/live.out" & pid=$!
for _ in $(seq 1 100); do pgrep -f "tail -n 0 -F $fx/live.jsonl" >/dev/null && break; timeout 0.1 tail -f /dev/null; done
jq -nc '{type:"user",timestamp:"2026-11-03T10:00:01Z",message:{content:"late"}}' >> "$fx/live.jsonl"
jq -nc '{type:"cost-state"}' >> "$fx/live.jsonl"
wait $pid; code=$?
check "a live watch starts at the end, follows new lines and stops itself" '[ $code = 0 ] && [ "$(cat "$fx/live.out")" = "[10:00:01] USER: late
HANDOFF" ]'
check "a stopped watch leaves no tail running" '! pgrep -f "tail -n 0 -F $fx/live.jsonl" >/dev/null'
check "the watch needs a transcript" '! bash "$tools/familiar-watch.sh" 2>/dev/null'

mkdir -p "$fx/p2/-r"
jq -nc '{type:"user",cwd:"/w",message:{content:"hi"}}' > "$fx/p2/-r/a.jsonl"
FAMILIAR_PROJECTS_DIR="$fx/p2" CLAUDE_CODE_SESSION_ID=me FAMILIAR_SESSIONS_EVERY=0.2 FAMILIAR_SESSIONS_ROUNDS=10 timeout 10 bash "$tools/familiar-sessions.sh" --new > "$fx/n2.out" & npid=$!
timeout 0.5 tail -f /dev/null
jq -nc '{type:"user",cwd:"/w",message:{content:"hi"}}' > "$fx/p2/-r/me.jsonl"
{ jq -nc '{type:"user",cwd:"/w",message:{content:"hi"}}'; jq -nc '{type:"cost-state"}'; } > "$fx/p2/-r/gone.jsonl"
wait $npid; ncode=$?
check "the new-session check stops itself after its rounds" '[ $ncode = 0 ]'
check "the new-session check never announces the familiar itself or an ended session" '[ ! -s "$fx/n2.out" ]'
# A session that started after the caller's own list but before this check
# began is still NEW, once, when the caller names what it already watches.
mkdir -p "$fx/p3/-r"
for i in known late; do jq -nc '{type:"user",cwd:"/w",message:{content:"hi"}}' > "$fx/p3/-r/$i.jsonl"; done
out=$(FAMILIAR_SESSIONS_DIR="$fx/no-records" FAMILIAR_PROJECTS_DIR="$fx/p3" CLAUDE_CODE_SESSION_ID=me FAMILIAR_SESSIONS_EVERY=0 FAMILIAR_SESSIONS_ROUNDS=2 timeout 10 bash "$tools/familiar-sessions.sh" --new known)
check "a session the caller doesn't watch is NEW, once" '[ "$out" = "NEW late $fx/p3/-r/late.jsonl /w" ]'
out=$(FAMILIAR_SESSIONS_DIR="$fx/no-records" FAMILIAR_PROJECTS_DIR="$fx/p3" CLAUDE_CODE_SESSION_ID=me FAMILIAR_SESSIONS_EVERY=0 FAMILIAR_SESSIONS_ROUNDS=2 timeout 10 bash "$tools/familiar-sessions.sh" --new)
check "with no ids named, the sessions live at the start are known" '[ -z "$out" ]'

# The familiar sees which skills start, and an agent line that asks, picks or
# waits is whole. Any other agent line is cut at 400 characters.
long=$(printf 'x%.0s' $(seq 1 450))
msg() { jq -nc --arg t "2026-11-03T10:00:$1Z" --arg m "$long $2" '{type:"assistant",timestamp:$t,message:{content:[{type:"tool_use",name:"SendUserMessage",input:{message:$m}}]}}'; }
{ jq -nc '{type:"assistant",timestamp:"2026-11-03T10:00:01Z",message:{content:[{type:"tool_use",name:"Skill",input:{skill:"vicky-skills:do"}}]}}'
  msg 02 "I picked the green one, done"
  msg 03 "fix
it?"
  msg 04 "My pick: yes"
  msg 05 "Waiting on you: the page"
  msg 06 "Going with B"
  jq -nc '{type:"assistant",timestamp:"2026-11-03T10:00:07Z",message:{content:[{type:"tool_use",name:"Bash",input:{command:"ls"}}]}}'
  jq -nc '{type:"cost-state"}'; } > "$fx/s.jsonl"
out=$(FAMILIAR_WATCH_FROM_START=1 timeout 10 bash "$tools/familiar-watch.sh" "$fx/s.jsonl")
at() { grep "^\[10:00:$1\] AGENT: " <<<"$out" | sed 's/^\[10:00:..\] AGENT: //'; }
check "a skill start is a SKILL line" 'grep -qx "\[10:00:01\] SKILL: do" <<<"$out"'
check "a plain agent line, a word holding pick included, is cut at 400" 'l=$(at 02); [ ${#l} = 400 ]'
check "an agent line that asks is whole, on one line" '[ "$(at 03)" = "$long fix it?" ]'
check "an agent line that picks is whole" '[ "$(at 04)" = "$long My pick: yes" ]'
check "an agent line that waits on the user is whole" '[ "$(at 05)" = "$long Waiting on you: the page" ]'
check "an agent line that takes a pick is whole" '[ "$(at 06)" = "$long Going with B" ]'
check "another tool call prints nothing" '! grep -q "10:00:07" <<<"$out"'

# S2's approved examples, held by the skill's words. They are plain regression
# tests: the skill text was written before these tests, so they could not go red first.
skill="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/skills/productivity/familiar/SKILL.md"
has() { grep -qF -- "$1" "$skill"; }
# Given the watch is armed / When an event shows a misread, a gate left unopened, a check the user did by hand, or a missing tool / Then the note gains one coded line: the time, what happened, the fix, and where the fix lands
check "S2 a snag is one coded line" 'has "adds one coded line to that session'"'"'s note: the time, what happened, the fix, and where the fix lands"'
# Given the watch is armed / When an event shows work going as asked / Then the note gains nothing and the user gets no message
check "S2 work going as asked adds nothing" 'has "A line that shows work going as asked adds nothing and sends the user nothing"'
# Given the watch is armed / When the agent checks something in the watched repo / Then it only reads: it runs no git command that writes and edits no file in that checkout
check "S2 a watched checkout is read only" 'has "In a watched checkout, only read: run no git command that writes, and edit no file there"'
# Given the watch is armed / When the watch expires with the session still live / Then the agent arms it again in the same turn
check "S2 an expired watch is armed again in the same turn" 'has "Each time a watch or the new-session check expires, arm it again in the same turn"'
# Given the note holds open lines / When the watch prints HANDOFF / Then each open line is built in the repo it belongs to, sent to that repo's session, or filed with a Waits on line, and the report lists every code with its outcome
check "S2 a handoff works every open line and reports each code" 'has "Build each open line in the repo it belongs to, send it to that repo'"'"'s session with \`SendMessage\`, or file it with a \`Waits on:\` line. Then report every code and its outcome"'
exit $fail
