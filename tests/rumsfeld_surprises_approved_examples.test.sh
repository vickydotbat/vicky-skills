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
# The settling step that logs the surprises.
step() { grep -E "^[0-9]+\. \*\*Log the surprises" make-it-so/SETTLE.md; }

# Given an asteroid belt found during a build, an unknown unknown that surfaced
# When make-it-so's settling closes the effort
# Then it is logged on the chart as an unknown unknown that became known, with what it cost
check "an asteroid belt found during a build is logged on the chart by the settling as an unknown unknown that became known, with what it cost" \
  'step | grep -q "asteroid belt" && step | grep -q "Surfaced:" && step | grep -q "cost" \
   && box "Unknown unknowns" | grep -q "^- Surfaced: .*cost"'
# Given a surprise of a kind seen before
# When a later chart sorts its knowns
# Then that kind is named in the unknown unknowns box as a risk to check
check "a surprise of a kind seen before is named in a later chart's unknown unknowns box as a risk to check" \
  'box "Unknown unknowns" | grep -q "^- Seen before: " && grep -q "earlier charts" "$chart" && grep -q "Surfaced:" "$chart"'
exit $fail
