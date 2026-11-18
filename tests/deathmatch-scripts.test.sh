#!/usr/bin/env bash
# The deathmatch scripts' decisions beyond their approved examples: cap.sh's
# exit codes and argument forms, and the usage errors of halfway.sh and
# verdict.sh.
set -u
dm="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/skills/shipping/deathmatch/scripts"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
bash "$dm/cap.sh" 10 64M -- bash -c 'exit 3'; r=$?
check "cap passes a command's own exit code through" '[ $r = 3 ]'
out=$(bash "$dm/cap.sh" 10 64M echo hi 2>&1); r=$?
check "cap runs a command given without --" '[ $r = 0 ] && [ "$out" = hi ]'
s=$(date +%s); bash "$dm/cap.sh" 10 64M -- true; r=$?; e=$(( $(date +%s) - s ))
check "cap returns as soon as a fast command ends" '[ $r = 0 ] && [ $e -lt 5 ]'
bash "$dm/cap.sh" 1 64M -- sleep 5 >/dev/null 2>&1; r=$?
check "cap exits 124 over the time cap" '[ $r = 124 ]'
out=$(bash "$dm/cap.sh" 10 32M -- python3 -c 'b = bytearray(256 * 1024 * 1024)' 2>/dev/null); r=$?
check "cap exits 125 over the memory cap" '[ $r = 125 ] && grep -q "memory cap" <<<"$out"'
out=$(bash "$dm/cap.sh" 10 64M -- bash -c 'echo plain failure >&2; exit 1' 2>/dev/null); r=$?
check "a failure that is no memory error stays the command's" '[ $r = 1 ] && [ -z "$out" ]'
bash "$dm/cap.sh" 10 lots -- true 2>/dev/null; r=$?
check "cap refuses a memory size it can't read" '[ $r = 2 ]'
bash "$dm/halfway.sh" four >/dev/null 2>&1; r=$?
check "halfway refuses a count that is no number" '[ $r = 2 ]'
bash "$dm/verdict.sh" check x y >/dev/null 2>&1; r=$?
check "verdict refuses a mode it doesn't know" '[ $r = 2 ]'
exit $fail
