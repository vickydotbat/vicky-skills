#!/usr/bin/env bash
# approved-spec: the examples approved on the star "Star chart sorts its
# knowns into four boxes". Each check is named after its example.
set -u
cd "$(dirname "$0")/../plugins/vicky-skills/skills/engineering"
chart=lay-course/STAR-CHART.md
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
# The chart body template: the lines between "## The chart" and "## Tickets".
body() { awk '/^## The chart/{on=1} /^## Tickets/{on=0} on' "$chart"; }
# One box of the Knowns section in the template, up to the next heading.
box() { body | awk -v h="### $1" '$0 == h {on=1; next} /^##/ {on=0} on'; }

check "a spec that mission-brief or lay-course writes is filed with a Knowns section holding the four boxes" \
  'body | awk "/^## Sensor log/{s=NR} /^## Knowns/{k=NR} END{exit !(s && k > s)}" \
   && [ "$(body | grep -cE "^### (Known knowns|Known unknowns|Unknown knowns|Unknown unknowns)$")" = 4 ] \
   && grep -q "Knowns" lay-course/SKILL.md && grep -q "Knowns" mission-brief/SKILL.md \
   && grep -qi "four Rumsfeld boxes" mission-brief/SKILL.md'
check "a known known sits in the sensor log with its source quoted" \
  'box "Known knowns" | grep -q "Sensor log" && body | grep -A2 "^## Sensor log" | grep -q "<the quoted line>"'
check "a known unknown is an anomaly or an away team ticket that blocks the stars resting on it" \
  'box "Known unknowns" | grep -q "anomaly or away team" && box "Known unknowns" | grep -q "blocking"'
check "an unknown known gets an away team to find the record, or one line for you to confirm, before any star rests on it" \
  'box "Unknown knowns" | grep -q "away team" && box "Unknown knowns" | grep -q "Confirm:" && grep -q "before any star rests on it" "$chart"'
check "the unknown unknowns box names the riskiest star and a timebox or probe, and is never left empty without saying why" \
  'box "Unknown unknowns" | grep -q "Riskiest star" && box "Unknown unknowns" | grep -q "timebox or a probe" && grep -q "never left empty" "$chart"'
exit $fail
