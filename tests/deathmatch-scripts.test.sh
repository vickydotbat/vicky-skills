#!/usr/bin/env bash
# The deathmatch scripts' decisions beyond their approved examples: cap.sh's
# exit codes and argument forms, and the usage errors of halfway.sh and
# verdict.sh.
set -u
dm="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/skills/shipping/deathmatch/scripts"
fail=0
tick=$((40000 + $$)); tick2=$((90000 + $$)) # unique to this run, so a run beside it never matches
# Mutant runs repeat the memory-hog checks many times. Each kill in a systemd scope
# raises a desktop notice, so inside a mutant run they take the fallback.
hog=(python3 -c 'b = bytearray(256 * 1024 * 1024)'); quiet=()
# A mutant that flips the scope choice would still kill a real hog, so in a
# mutant run the hog only prints the memory error the fallback reads.
[ -n "${MUTATE_HOOKS_INNER:-}" ] && { quiet=(CAP_NO_SCOPE=1); hog=(bash -c 'echo "Cannot allocate memory" >&2; exit 1'); }
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
rm -rf "$g"
exit $fail
