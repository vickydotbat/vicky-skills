#!/usr/bin/env bash
# "State at every stop" has one home, ship-it. The skills that stop point at it.
set -u
cd "$(dirname "$0")/.."
s=plugins/vicky-skills/skills; fail=0
grep -q '^## State at every stop' $s/shipping/ship-it/SKILL.md || { echo "FAIL ship-it lacks the State at every stop home"; fail=1; }
for k in do warp gamma-shift make-it-so; do
  grep -qF 'Write the Status section at every stop'  $s/*/$k/SKILL.md || { echo "FAIL $k does not point at ship-it"; fail=1; }
  grep -q "a slice parked, a gate reached, the run ended" $s/*/$k/SKILL.md && { echo "FAIL $k repeats the home text"; fail=1; }
done
[ $fail -eq 0 ] && echo "ok   state-at-every-stop: one home in ship-it, four pointers"
exit $fail
