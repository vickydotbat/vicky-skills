#!/usr/bin/env bash
# shellcheck disable=SC2016 # check() evals its single-quoted condition later
# shellcheck disable=SC2034 # names set here are read inside check()'s eval
# shellcheck disable=SC2164 # a failed cd fails the checks after it, which is the report
# The deathmatch scripts' decisions beyond their approved examples: cap.sh's
# exit codes and argument forms, and the usage errors of halfway.sh and
# verdict.sh.
set -u
dm="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/skills/shipping/deathmatch/scripts"
fail=0
tick=$((40000 + $$)); tick2=$((90000 + $$)) # unique to this run, so a run beside it never matches
. "$(dirname "$0")/lib/cap-hog.sh"
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
bash "$dm/cap.sh" 10 64M -- bash -c 'exit 3'; r=$?
check "cap passes a command's own exit code through" '[ $r = 3 ]'
out=$(bash "$dm/cap.sh" 10 64M echo hi 2>&1); r=$?
check "cap runs a command given without --" '[ $r = 0 ] && [ "$out" = hi ]'
s=$(date +%s); bash "$dm/cap.sh" 10 64M -- true; r=$?; e=$(( $(date +%s) - s ))
check "cap returns as soon as a fast command ends" '[ $r = 0 ] && [ $e -lt 5 ]'
bash "$dm/cap.sh" 1 64M -- sleep 5 >/dev/null 2>&1; r=$?
check "cap exits 124 over the time cap" '[ $r = 124 ]'
out=$(env ${quiet[@]+"${quiet[@]}"} bash "$dm/cap.sh" 10 32M -- "${hog[@]}" 2>/dev/null); r=$?
check "cap exits 125 over the memory cap" '[ $r = 125 ] && grep -q "memory cap of 32M (unproven" <<<"$out"'
out=$(bash "$dm/cap.sh" 10 64M -- bash -c 'echo plain failure >&2; exit 1' 2>/dev/null); r=$?
check "a failure that is no memory error stays the command's" '[ $r = 1 ] && [ -z "$out" ]'
bash "$dm/cap.sh" 10 lots -- true 2>/dev/null; r=$?
check "cap refuses a memory size it can't read" '[ $r = 2 ]'
bash "$dm/halfway.sh" four >/dev/null 2>&1; r=$?
check "halfway refuses a count that is no number" '[ $r = 2 ]'
bash "$dm/verdict.sh" check x y >/dev/null 2>&1; r=$?
check "verdict refuses a mode it doesn't know" '[ $r = 2 ]'
# Found by the deathmatch on its own pull request.
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
printf 'MemAvailable: 67108864 kB\n' > "$t/mem64g"
bash "$dm/cap.sh" 3 64M -- bash -c 'sleep 301 & echo $! > "'"$t"'/bg"; exit 0'; r=$?; bg=$(cat "$t/bg")
check "a clean exit leaves no child of the command behind" '[ $r = 0 ] && ! kill -0 $bg 2>/dev/null'
kill "$bg" 2>/dev/null
if systemd-run --user --scope -q true 2>/dev/null; then
bash "$dm/cap.sh" 1 64M -- bash -c 'setsid sleep 302 >/dev/null 2>&1 & echo $! > "'"$t"'/ss"; sleep 30' >/dev/null; ss=$(cat "$t/ss")
check "a setsid grandchild dies with the time cap" '! kill -0 $ss 2>/dev/null'
kill "$ss" 2>/dev/null
else echo "skip a setsid grandchild dies with the time cap: no systemd user manager"; fi
out=$(CAP_NO_SCOPE=1 bash "$dm/cap.sh" 10 32M -- "${hog[@]}" 2>/dev/null); r=$?
check "with no scope, the memory cap still holds" '[ $r = 125 ]'
out=$(bash "$dm/cap.sh" 10 64M -- bash -c 'exit 143'); r=$?
check "a command's own exit 143 is no time cap" '[ $r = 143 ] && [ -z "$out" ]'
bash "$dm/cap.sh" "$tick" 64M -- true
check "a fast command leaves no timer behind" '! pgrep -fx "sleep $tick" >/dev/null'
out=$(bash "$dm/cap.sh" 10 64M -- python3 -c 'import os; os.kill(os.getpid(), 9)'); r=$?
check "a command that kills itself is no time cap" '[ $r = 137 ] && ! grep -q "time cap" <<<"$out"'
h=$(bash "$dm/halfway.sh" 010)
check "halfway reads a leading zero as decimal" '[ "$h" = "after 5: standards" ]'
bash "$dm/halfway.sh" 08 >/dev/null 2>&1; r=$?; h=$(bash "$dm/halfway.sh" 08 2>/dev/null)
check "halfway takes 08 as eight" '[ $r = 0 ] && [ "$h" = "after 4: standards" ]'
bash "$dm/verdict.sh" due "$t/none" "" >/dev/null 2>&1; r=$?
check "verdict refuses an empty sha, never calling it done" '[ $r = 2 ]'
mkdir "$t/r" && cd "$t/r" && git init -qb main && git config user.email t@t && git config user.name t
printf 'one\ntwo\nthree\nfour\n' > o.txt && git add . && git commit -qm o && base=$(git rev-parse HEAD)
git mv o.txt n.txt && printf 'log=/ho''me/bob/x\n' >> n.txt && git commit -qam r
out=$(bash "$dm/prefight.sh" "$base"); r=$?
check "a leak in a renamed file is caught" '[ $r = 1 ] && grep -q "n.txt:5" <<<"$out"'
git reset -q --hard "$base" && printf 'log=/ho''me/bob\n' >> o.txt && git commit -qam bare
out=$(bash "$dm/prefight.sh" "$base"); r=$?
check "a home folder at the end of a line is caught" '[ $r = 1 ] && grep -q "o.txt:5" <<<"$out"'
git reset -q --hard "$base" && printf 'see /home/ for the layout\n' >> o.txt && git commit -qam bare
bash "$dm/prefight.sh" "$base" >/dev/null; r=$?
check "a bare /home/ with no user passes" '[ $r = 0 ]'
cd - >/dev/null
bash "$dm/batch.sh" none >/dev/null 2>&1; r=$?
check "batch refuses a count that is no number" '[ $r = 2 ]'
bash "$dm/batch.sh" 0 >/dev/null 2>&1; r=$?
check "batch refuses no opponents" '[ $r = 2 ]'
h=$(BATCH_MEMINFO="$t/mem64g" bash "$dm/batch.sh" 03)
check "batch reads a leading zero as decimal" 'grep -qx "at once: 3" <<<"$h"'
h=$(bash "$dm/batch.sh" 1)
check "one opponent fights alone" 'grep -qx "at once: 1" <<<"$h"'
# Found by the mutation pass.
lim=$(CAP_NO_SCOPE=1 bash "$dm/cap.sh" 10 64M -- bash -c 'ulimit -v' 2>/dev/null)
check "CAP_NO_SCOPE runs the fallback's address-space cap" '[ "$lim" = 65536 ]'
CAP_NO_SCOPE=1 bash "$dm/cap.sh" 10 64M -- bash -c "sleep $tick2 & exit 0" >/dev/null 2>&1
check "the fallback kills what the command left running" '! pgrep -fx "sleep $tick2" >/dev/null'
g=$(mktemp -d)
bash "$dm/cap.sh" 1 64M -- bash -c "trap 'sleep 0.3; echo graceful > $g/term; exit 0' TERM; while :; do sleep 0.1; done" >/dev/null 2>&1
check "over the time cap, a command gets a moment to stop after TERM" '[ -s "$g/term" ]'
failed() { systemctl --user list-units --failed --plain --no-legend "cap-*" 2>/dev/null | wc -l; }
f0=$(failed); env ${quiet[@]+"${quiet[@]}"} bash "$dm/cap.sh" 10 32M -- "${hog[@]}" >/dev/null 2>&1; f1=$(failed)
check "a memory cap leaves no failed unit behind" '[ "$f1" -le "$f0" ]'
out=$(CAP_NO_SCOPE=1 bash "$dm/cap.sh" 10 64M -- bash -c 'echo out of memory >&2; exit 0' 2>/dev/null); r=$?
check "the fallback calls no memory cap on a command that succeeded" '[ $r = 0 ] && [ -z "$out" ]'
out=$(CAP_NO_SCOPE=1 bash "$dm/cap.sh" 10 64M -- bash -c 'echo plain failure >&2; exit 3' 2>/dev/null); r=$?
check "the fallback calls no memory cap on a plain failure" '[ $r = 3 ] && [ -z "$out" ]'
(cd "$g" && git init -q -b main && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m base && git switch -qc b && echo x > a.sh && git add a.sh && git -c user.email=t@t -c user.name=t commit -qm add)
printf '## Summary\nFixes the crash on an empty name.\n' > "$g/body.md"
out=$(cd "$g" && bash "$dm/triggers.sh" main "$g/body.md" 2>&1)
check "a fix claimed only in the body brings Cause" 'grep -qx "fight: cause" <<<"$out"'
out=$(BATCH_MEMINFO="$t/mem64g" bash "$dm/batch.sh" 08 2>&1)
check "batch takes 08 as eight" 'grep -qx "at once: 3" <<<"$out"'
out=$(BATCH_MEMINFO="$t/mem64g" bash "$dm/batch.sh" 02 2>&1)
check "batch prints 02 as two at once" 'grep -qx "at once: 2" <<<"$out"'
out=$(BATCH_MEMINFO="$t/mem64g" bash "$dm/batch.sh" holds 2>&1)
check "Holds fights alone" 'grep -qx "at once: 1" <<<"$out"'
check "Holds gets room for a mutation pass, up to 6G" 'grep -qx "memory cap: 6.0G" <<<"$out"'
printf 'MemAvailable:    8388608 kB\n' > "$t/mem8g"
out=$(BATCH_MEMINFO="$t/mem8g" bash "$dm/batch.sh" holds 2>&1)
check "Holds takes half the memory free when that is under 6G" 'grep -qx "memory cap: 4.0G" <<<"$out"'
out=$(BATCH_MEMINFO="$t/mem8g" bash "$dm/batch.sh" 1 2>&1)
check "a count keeps its 2G ceiling" 'grep -qx "memory cap: 2.0G" <<<"$out"'
printf 'MemAvailable:    1048576 kB\n' > "$t/mem1g"
out=$(BATCH_MEMINFO="$t/mem1g" bash "$dm/batch.sh" holds 2>&1)
check "Holds under 1G warns that a cap finding is unproven" 'grep -q "under 1G" <<<"$out"'
out=$(BATCH_MEMINFO=/dev/null bash "$dm/batch.sh" holds 2>&1); r=$?
check "batch with no MemAvailable stops and says so" '[ $r = 2 ] && grep -q "no MemAvailable" <<<"$out"'
printf 'MemAvailable:    abc kB\n' > "$t/membad"
out=$(BATCH_MEMINFO="$t/membad" bash "$dm/batch.sh" holds 2>&1); r=$?
check "batch with an unreadable MemAvailable stops and says so" '[ $r = 2 ] && grep -q "no MemAvailable" <<<"$out"'
printf 'MemAvailable:    0 kB\n' > "$t/mem0"
out=$(BATCH_MEMINFO="$t/mem0" bash "$dm/batch.sh" 2 2>&1); r=$?
check "batch with no memory free stops and says so" '[ $r = 2 ] && grep -q "no MemAvailable" <<<"$out"'
rm -rf "$g"
mkdir "$t/v" && git -C "$t/v" init -qb feat && git -C "$t/v" -c user.email=t@t -c user.name=t commit -q --allow-empty -m v
(cd "$t/v" && env -u CLAUDE_CODE_SESSION_ID bash "$dm/verdict.sh" record) >/dev/null 2>&1; r=$?
check "record without a session id refuses" '[ $r = 2 ] && [ ! -e "$t/v/.git/vicky-skills" ]'
(cd "$t/v" && env -u CLAUDE_CODE_SESSION_ID bash "$dm/verdict.sh" record s1 && env -u CLAUDE_CODE_SESSION_ID bash "$dm/verdict.sh" record s2); r=$?
h=$(git -C "$t/v" rev-parse HEAD)
check "record writes each session id with the head commit for the branch" '[ $r = 0 ] && [ "$(cat "$t/v/.git/vicky-skills/deathmatch/feat")" = "$(printf "s1 %s\ns2 %s" "$h" "$h")" ]'
git -C "$t/v" checkout -q --detach
(cd "$t/v" && env -u CLAUDE_CODE_SESSION_ID bash "$dm/verdict.sh" record s3) >/dev/null 2>&1; r=$?
check "record off a branch refuses and writes nothing" '[ $r = 2 ] && ! grep -q s3 -r "$t/v/.git/vicky-skills"'
(cd "$t/v" && git checkout -q feat && env -u CLAUDE_CODE_SESSION_ID bash "$dm/verdict.sh" record s4 >/dev/null 2>&1; echo $?) >"$t/rc"
check "record exits 0" '[ "$(cat "$t/rc")" = 0 ]'
(cd "$t/v" && CLAUDE_CODE_SESSION_ID=me bash "$dm/verdict.sh" record other) >"$t/out" 2>&1; r=$?
check "record refuses a session id that is not this session's, and names this one" '[ $r = 2 ] && grep -q "this session is me" "$t/out" && ! grep -q "^other " "$t/v/.git/vicky-skills/deathmatch/feat"'
(cd "$t/v" && CLAUDE_CODE_SESSION_ID=me bash "$dm/verdict.sh" record me >/dev/null 2>&1); r=$?
check "record takes this session's own id" '[ $r = 0 ] && grep -q "^me " "$t/v/.git/vicky-skills/deathmatch/feat"'
CLAUDE_PLUGIN_DATA='' PLUGIN_DATA="$t/mo-pd" bash "$dm/mark-outside.sh" s1 "pr 7"
check "mark-outside resolves PLUGIN_DATA when CLAUDE_PLUGIN_DATA is unset" '[ "$(cat "$t/mo-pd/outside-read/s1")" = "pr 7" ]'
agy_dm="$t/.gemini/config/plugins/vicky-skills"
mkdir -p "$agy_dm/scripts" "$agy_dm/skills/deathmatch/scripts"
cp "$dm/../../../../scripts/plugin-data.sh" "$agy_dm/scripts/"
cp "$dm/mark-outside.sh" "$agy_dm/skills/deathmatch/scripts/"
CLAUDE_PLUGIN_DATA='' PLUGIN_DATA='' bash "$agy_dm/skills/deathmatch/scripts/mark-outside.sh" s2 "issue 9"
check "mark-outside resolves Antigravity flattened plugin_data" '[ "$(cat "$t/.gemini/antigravity/plugin_data/vicky-skills/outside-read/s2")" = "issue 9" ]'
# An assimilate verdict is the work list: carry its patch past a due deathmatch,
# and pick the newer of it and the body.
printf 'Proof\nDeathmatch verdict for aaa1111: 2 proven findings\n' > "$t/body"
bash "$dm/verdict.sh" carry "$t/body" bbb2222 aaa1111 >/dev/null 2>&1; r=$?
check "carry marks the head commit as holding the verdict it applies" '[ $r = 0 ] && grep -q "Deathmatch verdict for bbb2222: carried from aaa1111" "$t/body"'
bash "$dm/verdict.sh" due "$t/body" bbb2222 >/dev/null 2>&1; r=$?
check "a carried head commit is no longer due" '[ $r = 1 ]'
bash "$dm/verdict.sh" due "$t/body" ccc3333 >/dev/null 2>&1; r=$?
check "a commit after the carried one is due again" '[ $r = 0 ]'
cp "$t/body" "$t/body.before"
bash "$dm/verdict.sh" carry "$t/body" ddd4444 zzz9999 >/dev/null 2>&1; r=$?
check "carry refuses a verdict the body never held, and writes nothing" '[ $r = 1 ] && cmp -s "$t/body" "$t/body.before"'
bash "$dm/verdict.sh" carry "$t/body" ddd4444 >/dev/null 2>&1; r=$?
check "carry with a missing argument is a usage error" '[ $r = 2 ]'
as="$dm/assimilate-source.sh"
cat > "$t/c.json" <<'JSON'
[{"id":11,"body":"Looks fine, but see The patch below.","created_at":"2026-11-20T10:00:00Z","updated_at":"2026-11-20T10:00:00Z"},
 {"id":12,"body":"Assimilate verdict for abc1234\n## The four answers\n...\n## The patch\n...\n## Unproven, not blocking\n...","created_at":"2026-11-21T10:00:00Z","updated_at":"2026-11-21T10:00:00Z"},
 {"id":13,"body":"## The four answers\nx\n## The patch\ny\n## What stays\nz","created_at":"2026-11-22T10:00:00Z","updated_at":"2026-11-22T10:00:00Z"}]
JSON
out=$(bash "$as" "$t/c.json" 2026-11-21T12:00:00Z); r=$?
check "the newest assimilate comment wins over an older body" '[ $r = 0 ] && [ "$out" = "comment 13" ]'
out=$(bash "$as" "$t/c.json" 2026-11-23T00:00:00+00:00)
check "a body edited after the comment wins" '[ "$out" = body ]'
out=$(bash "$as" "$t/c.json" 2026-11-22T10:00:00Z)
check "a body edited at the comment's own second wins the tie" '[ "$out" = body ]'
out=$(bash "$as" "$t/c.json" 2026-11-22T11:00:00+02:00)
check "times compare across time zones" '[ "$out" = "comment 13" ]'
echo '[{"id":1,"body":"Assimilate verdict for abc1234","created_at":"2026-11-21T10:00:00Z"}]' > "$t/m.json"
out=$(bash "$as" "$t/m.json" 2026-11-01T00:00:00Z)
check "the marker line alone marks an assimilate comment, with no updated_at" '[ "$out" = "comment 1" ]'
echo '[{"id":1,"body":"The patch is wrong","created_at":"2026-11-21T10:00:00Z"}]' > "$t/n.json"
out=$(bash "$as" "$t/n.json" 2026-11-01T00:00:00Z)
check "a plain review comment is no assimilate comment" '[ "$out" = none ]'
echo '[]' > "$t/e.json"
out=$(bash "$as" "$t/e.json" 2026-11-01T00:00:00Z)
check "no comments is none" '[ "$out" = none ]'
bash "$as" "$t/c.json" no-such-time >/dev/null 2>&1; r=$?
check "a body time that is no time is a usage error" '[ $r = 2 ]'
bash "$as" "$t/nofile.json" 2026-11-01T00:00:00Z >/dev/null 2>&1; r=$?
check "an unreadable comments file is a usage error" '[ $r = 2 ]'
bash "$dm/verdict.sh" carry "$t/body" "" aaa1111 >/dev/null 2>&1; r=$?
check "carry with an empty head sha is a usage error" '[ $r = 2 ]'
bash "$dm/verdict.sh" carry "" ddd4444 aaa1111 >/dev/null 2>&1; r=$?
check "carry with an empty body path is a usage error" '[ $r = 2 ]'
(cd "$t/v" && env -u CLAUDE_CODE_SESSION_ID bash "$dm/verdict.sh" carry "$t/body" eee5555 aaa1111 s9) >/dev/null 2>&1; r=$?
check "carry with a session id records that session for the branch" '[ $r = 0 ] && grep -q "^s9 " "$t/v/.git/vicky-skills/deathmatch/feat"'
echo '[{"id":1,"body":"Assimilate verdict for abc1234","created_at":"2026-11-21T10:00:00Z"}]' > "$t/m.json"
bash "$as" "$t/m.json" "" >/dev/null 2>&1; r=$?
check "an empty body time is a usage error" '[ $r = 2 ]'
echo 'not json' > "$t/bad.json"
bash "$as" "$t/bad.json" 2026-11-01T00:00:00Z >/dev/null 2>&1; r=$?
check "a file that is no JSON is a usage error" '[ $r = 2 ]'
echo '[{"id":5,"body":"Assimilate verdict for abc1234","created_at":"garbage"}]' > "$t/g.json"
bash "$as" "$t/g.json" 2026-11-01T00:00:00Z >/dev/null 2>&1; r=$?
check "an assimilate comment with no readable time is a usage error" '[ $r = 2 ]'
bash "$as" "$t/e.json" 2026-11-01T00:00:00Z >/dev/null 2>&1; r=$?
check "none exits 0" '[ $r = 0 ]'
# Deathmatch findings on 83ebef4a: Gitea's offset times, sha prefixes, a body with no last newline, a heading named in prose.
cat > "$t/o.json" <<'JSON'
[{"id":1,"body":"Assimilate verdict for abc1234","created_at":"2026-11-25T11:00:00+02:00","updated_at":"2026-11-25T11:00:00+02:00"},
 {"id":2,"body":"Assimilate verdict for abc1234","created_at":"2026-11-25T10:30:00+02:00","updated_at":"2026-11-25T10:30:00+02:00"}]
JSON
out=$(bash "$as" "$t/o.json" 2026-11-25T00:00:00Z)
check "the newest of several comments with offset times wins" '[ "$out" = "comment 1" ]'
cat > "$t/p.json" <<'JSON'
[{"id":1,"body":"## The four answers\nx\n## The patch\ny","created_at":"2026-11-21T10:00:00Z"},
 {"id":2,"body":"see The four answers and The patch above","created_at":"2026-11-22T10:00:00Z"}]
JSON
out=$(bash "$as" "$t/p.json" 2026-11-01T00:00:00Z)
check "a comment that names the headings in prose is no assimilate comment" '[ "$out" = "comment 1" ]'
printf 'Deathmatch verdict for abc1234567: 0 proven findings\n' > "$t/pb"
bash "$dm/verdict.sh" carry "$t/pb" fff0000 abc12 >/dev/null 2>&1; r=$?
check "carry refuses a sha that only prefixes the verdict's" '[ $r != 0 ] && ! grep -q fff0000 "$t/pb"'
bash "$dm/verdict.sh" due "$t/pb" abc12; r=$?
check "due holds a sha that only prefixes the verdict's as due" '[ $r = 0 ]'
bash "$dm/verdict.sh" due "$t/pb" a.c1234567; r=$?
check "due reads the sha as text, not a pattern" '[ $r != 1 ]'
printf 'Deathmatch verdict for aaa1111: 0 proven findings\n- last line' > "$t/nb"
bash "$dm/verdict.sh" carry "$t/nb" bbb2222 aaa1111 >/dev/null 2>&1
check "carry starts its line on a line of its own" 'grep -q "^- last line$" "$t/nb" && grep -q "^Deathmatch verdict for bbb2222: carried" "$t/nb"'
printf 'Deathmatch verdict for aaa1111: 0 proven findings\n' > "$t/eb"
bash "$dm/verdict.sh" carry "$t/eb" bbb2222 aaa1111 >/dev/null 2>&1
check "carry after a last newline adds no blank line" '[ "$(grep -c "^$" "$t/eb")" = 0 ]'
cp "$t/body" "$t/body.before"
(cd "$t/v" && CLAUDE_CODE_SESSION_ID=me bash "$dm/verdict.sh" carry "$t/body" ggg7777 aaa1111 other) >"$t/out" 2>&1; r=$?
check "carry refuses another session's id, names this one, and writes nothing" '[ $r = 2 ] && grep -q "this session is me" "$t/out" && cmp -s "$t/body" "$t/body.before" && ! grep -q "^other " "$t/v/.git/vicky-skills/deathmatch/feat"'
# verdict.sh since: only a verdict commit still in HEAD's history is a fixed point.
git init -qb main "$t/sn" && git -C "$t/sn" -c user.name=t -c user.email=t@t commit -q --allow-empty -m a && a=$(git -C "$t/sn" rev-parse HEAD)
git -C "$t/sn" -c user.name=t -c user.email=t@t commit -q --allow-empty -m b && b=$(git -C "$t/sn" rev-parse HEAD)
git -C "$t/sn" switch -qc side "$a" && git -C "$t/sn" -c user.name=t -c user.email=t@t commit -q --allow-empty -m s && side=$(git -C "$t/sn" rev-parse HEAD) && git -C "$t/sn" switch -q main
printf 'Deathmatch verdict for %s: 0 proven findings\nDeathmatch verdict for %s: 0 proven findings\nDeathmatch verdict for %s: 1 proven findings\n' "$a" "$b" "$side" > "$t/sn.md"
out=$(cd "$t/sn" && bash "$dm/verdict.sh" since "$t/sn.md"); r=$?
check "since skips a newer verdict whose commit left HEAD's history, and takes the newest one in it" '[ $r = 0 ] && [ "$out" = "$b" ]'
printf 'Deathmatch verdict for %s: 0 proven findings\n' "$side" > "$t/sn2.md"
out=$(cd "$t/sn" && bash "$dm/verdict.sh" since "$t/sn2.md"); r=$?
check "since prints nothing and exits 1 when no verdict commit is in HEAD's history" '[ $r = 1 ] && [ -z "$out" ]'
(cd "$t/sn" && bash "$dm/verdict.sh" since "$t/missing.md") >/dev/null 2>&1; r=$?
check "since refuses a body file that doesn't exist" '[ $r = 2 ]'
exit $fail
