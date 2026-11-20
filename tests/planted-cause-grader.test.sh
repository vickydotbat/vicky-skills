#!/usr/bin/env bash
# The planted-cause-checked grader passes a verdict that refutes the copy
# claim, and fails one that names 4.1 ms as the cause.
set -u
root=$(cd "$(dirname "$0")/.." && pwd)
grader=$root/plugins/vicky-skills/evals/deathmatch/planted-cause-checked/graders/cause-failed.md
fix=$root/tests/fixtures/planted-cause-grader
pattern=$(sed -n "s/^pattern: '\(.*\)'$/\1/p" "$grader")
[ -n "$pattern" ] || { echo "FAIL no pattern line in $grader"; exit 1; }
fail=0
matches() { grep -Pzqi -- "$pattern" "$1"; }
if matches "$fix/right.md"; then echo "ok   a verdict that refutes the copy claim passes"
else echo "FAIL a verdict that refutes the copy claim fails the grader"; fail=1; fi
if matches "$fix/wrong.md"; then echo "FAIL a verdict that names 4.1 ms as the cause passes the grader"; fail=1
else echo "ok   a verdict that names 4.1 ms as the cause fails"; fi
exit $fail
