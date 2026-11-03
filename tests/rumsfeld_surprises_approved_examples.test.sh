#!/usr/bin/env bash
# approved-spec: the examples approved on the star "Surprises feed back into
# the next sort". Each check is named after its example.
set -u
cd "$(dirname "$0")/../plugins/vicky-skills/skills/engineering"
chart=lay-course/STAR-CHART.md
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
body() { awk '/^## The chart/{on=1} /^## Tickets/{on=0} on' "$chart"; }
box() { body | awk -v h="### $1" '$0 == h {on=1; next} /^##/ {on=0} on'; }
# The loose-ends step that logs the surprises.
step() { grep -E "^[0-9]+\. \*\*Log the surprises" loose-ends/SKILL.md; }

check "an asteroid belt found during a build is logged on the chart by loose-ends as an unknown unknown that became known, with what it cost" \
  'step | grep -q "asteroid belt" && step | grep -q "Surfaced:" && step | grep -q "cost" \
   && box "Unknown unknowns" | grep -q "^- Surfaced: .*cost"'
check "a surprise of a kind seen before is named in a later chart'\''s unknown unknowns box as a risk to check" \
  'box "Unknown unknowns" | grep -q "^- Seen before: " && grep -q "earlier charts" "$chart" && grep -q "Surfaced:" "$chart"'
exit $fail
