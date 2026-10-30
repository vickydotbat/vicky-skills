#!/usr/bin/env bash
# approved-spec: the examples approved on the star "Asteroid belts and black
# holes in the star chart words". Each check is named after its example.
set -u
cd "$(dirname "$0")/../plugins/vicky-skills/skills/engineering"
chart=lay-course/STAR-CHART.md
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
row() { grep -E "^\| \*\*$1\*\* \|" "$chart"; }
# The chart body template: the lines between "## The chart" and "## Tickets".
body() { awk '/^## The chart/{on=1} /^## Tickets/{on=0} on' "$chart"; }

check "an agent looking up \"asteroid belt\" reads a question found during a build that the target can't ship without" \
  'row "asteroid belt" | grep -q "found during a build" && row "asteroid belt" | grep -q "can.t ship without"'
check "the warp skill points to the star chart words for \"asteroid belt\" instead of defining it again" \
  'grep -i "asteroid belt" warp/SKILL.md | grep -q "STAR-CHART.md" && ! grep -i "asteroid belt" warp/SKILL.md | grep -q "can.t ship without"'
check "an agent looking up \"black hole\" reads a part of the work that eats effort without end, which the course steers around" \
  'row "black hole" | grep -q "eats effort without end" && row "black hole" | grep -q "steers around"'
check "a black hole gets no ticket and no starchart label" \
  'row "black hole" | grep -q "never a ticket" && ! grep -rq "starchart:black" .'
check "a new chart body has a Black holes section after Decisions, each line naming a black hole and its way around" \
  'body | awk "/^## Decisions/{d=NR} /^## Black holes/{b=NR} END{exit !(d && b > d)}" && body | grep -A3 "^## Black holes" | grep -q "way around" && grep -q "Black holes" lay-course/SKILL.md'
check "a new chart with no black hole seen yet has a Black holes section reading \"None seen yet.\"" \
  'grep -q "None seen yet\." "$chart"'
exit $fail
