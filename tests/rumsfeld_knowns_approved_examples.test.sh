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

# Given a spec that mission-brief or lay-course writes
# When it is filed as a star chart
# Then the chart body has a Knowns section with four boxes: known knowns, known unknowns, unknown knowns and unknown unknowns
check "a spec that mission-brief or lay-course writes is filed with a Knowns section holding the four boxes" \
  'body | awk "/^## Sensor log/{s=NR} /^## Knowns/{k=NR} END{exit !(s && k > s)}" \
   && [ "$(body | grep -cE "^### (Known knowns|Known unknowns|Unknown knowns|Unknown unknowns)$")" = 4 ] \
   && grep -q "Knowns" lay-course/SKILL.md && grep -q "Knowns" mission-brief/SKILL.md \
   && grep -qi "four Rumsfeld boxes" mission-brief/SKILL.md'
# Given a known known in the spec
# When the chart is filed
# Then it sits in the sensor log with its source quoted
check "a known known sits in the sensor log with its source quoted" \
  'box "Known knowns" | grep -q "Sensor log" && body | grep -A2 "^## Sensor log" | grep -q "<the quoted line>"'
# Given a known unknown
# When the chart is filed
# Then it is an anomaly or an away team ticket that blocks the stars resting on it
check "a known unknown is an anomaly or an away team ticket that blocks the stars resting on it" \
  'box "Known unknowns" | grep -q "anomaly or away team" && box "Known unknowns" | grep -q "blocking"'
# Given an unknown known, something likely written down somewhere or held in your head but not said
# When the chart is filed
# Then it gets an away team to find the record, or one line for you to confirm, before any star rests on it
check "an unknown known gets an away team to find the record, or one line for you to confirm, before any star rests on it" \
  'box "Unknown knowns" | grep -q "away team" && box "Unknown knowns" | grep -q "Confirm:" && grep -q "before any star rests on it" "$chart"'
# Given the unknown unknowns box
# When the chart is filed
# Then it names the riskiest star and a timebox or probe for it, and is never left empty without saying why
check "the unknown unknowns box names the riskiest star and a timebox or probe, and is never left empty without saying why" \
  'box "Unknown unknowns" | grep -q "Riskiest star" && box "Unknown unknowns" | grep -q "timebox or a probe" && grep -q "never left empty" "$chart"'
exit $fail
