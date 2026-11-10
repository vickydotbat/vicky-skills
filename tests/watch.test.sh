#!/usr/bin/env bash
# watch.sh's edges: its help, bad arguments, and no sleep after the last round.
set -u
watch="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/watch.sh"
fail=0
expect() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: want $2, got $3"; fail=1; fi; }
expect "--help exits 0" 0 "$(bash "$watch" --help >/dev/null; echo $?)"
expect "--help prints the usage line and the three lines on pace, output and exits" 4 "$(bash "$watch" --help | grep -cE "^usage: watch.sh|every 30 seconds|output each time it changes|exits 0, and 3")"
expect "no check is a usage error" 2 "$(bash "$watch" --every 1 2>/dev/null; echo $?)"
expect "a pace that is not a number is a usage error" 2 "$(bash "$watch" true --every x 2>/dev/null; echo $?)"
expect "the usage goes to stderr on an error" "" "$(bash "$watch" 2>/dev/null)"
start=$(date +%s)
bash "$watch" false --every 5 --rounds 1 >/dev/null
expect "the last round ends without a sleep" 1 "$(( $(date +%s) - start < 3 ))"
start=$(date +%s)
bash "$watch" false --every 1 --rounds 2 >/dev/null
expect "rounds before the last one sleep" 1 "$(( $(date +%s) - start >= 1 ))"
expect "a pgrep -f check is refused, since it matches the watch itself" 2 "$(bash "$watch" '! pgrep -f blender' --rounds 1 2>/dev/null; echo $?)"
expect "a pgrep -af check is refused too" 2 "$(bash "$watch" 'pgrep -af x' --rounds 1 2>/dev/null; echo $?)"
expect "the refusal names kill -0" 1 "$(bash "$watch" 'pgrep -f x' 2>&1 | grep -c 'kill -0')"
expect "a pgrep -x check runs" 0 "$(bash "$watch" '! pgrep -x no-such-proc-zz' --rounds 1 >/dev/null 2>&1; echo $?)"
exit $fail
