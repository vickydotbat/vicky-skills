#!/usr/bin/env bash
# Regression test for the readiness star's example on answering a Confirm
# line, approved after the behaviour shipped, so it carries no approved mark:
# Given an unknown known with a Confirm line behind a star
# When you answer it
# Then the fact moves to the Sensor log quoting you, the star loses that unknown, and it can reach the frontier
set -u
here="$(cd "$(dirname "$0")" && pwd)"
cd "$here/../plugins/vicky-skills/skills/engineering/lay-course"
fail=0
grep -q "Once the user confirms, the fact moves to the Sensor log, quoting the user, and its star loses that unknown at the next redraw" STAR-CHART.md \
  || { echo "FAIL the sort no longer says a confirmed fact moves to the Sensor log and drops its unknown"; fail=1; }
tickets=$(mktemp); trap 'rm -f "$tickets"' EXIT
# The same star before and after its one Confirm line is answered.
echo '[{"key": "K-1", "kind": "star", "title": "Before", "open": true, "known": 1, "unknown": 1}]' > "$tickets"
python3 scripts/draw-chart.py "$tickets" | grep -q "class T1 frontier" && { echo "FAIL a star with an unanswered Confirm line is on the frontier"; fail=1; }
echo '[{"key": "K-1", "kind": "star", "title": "After", "open": true, "known": 2, "unknown": 0}]' > "$tickets"
python3 scripts/draw-chart.py "$tickets" | grep -q "class T1 frontier" || { echo "FAIL a star whose Confirm line was answered stays off the frontier"; fail=1; }
[ $fail -eq 0 ] && echo "ok   an answered Confirm line moves its fact to the Sensor log and frees its star"
exit $fail
