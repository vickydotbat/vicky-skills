#!/usr/bin/env bash
# approved-spec: the examples approved on the star "The chart drawing shows
# black holes". Each check is named after its example.
set -u
here="$(dirname "$0")/../plugins/vicky-skills/skills/engineering/lay-course"
script="$here/scripts/draw-chart.py"
scratch=$(mktemp -d); trap 'rm -rf "$scratch"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
draw() { printf '%s' "$1" > "$scratch/t.json"; python3 "$script" "$scratch/t.json" ${2:+--course "$2"} 2>&1; }

one=$(draw '[{"key": "K-1", "kind": "star", "title": "Build", "open": true},
 {"black_hole": "Rewrite every tell", "threatens": ["K-1"]}]')
check "a black hole that threatens one open star is drawn as a dark node of its own, joined to that star by a dotted line" \
  'grep -qF "H1((\"black hole: Rewrite every tell\"))" <<<"$one" && grep -qF "H1 -. threatens .- T1" <<<"$one" && grep -q "^  class H1 blackhole$" <<<"$one" && grep -q "classDef blackhole fill:#111827" <<<"$one"'

two=$(draw '[{"key": "K-1", "kind": "star", "title": "A", "open": true},
 {"key": "K-2", "kind": "task", "title": "B", "open": true},
 {"black_hole": "Scope creep", "threatens": ["K-1", "K-2"]}]')
check "a black hole that threatens two open tickets is one node, with a dotted line to each ticket" \
  '[ "$(grep -c "((\"black hole: " <<<"$two")" -eq 1 ] && grep -qF "H1 -. threatens .- T1" <<<"$two" && grep -qF "H1 -. threatens .- T2" <<<"$two"'

closed=$(draw '[{"key": "K-1", "kind": "star", "title": "Done", "open": false},
 {"key": "K-2", "kind": "star", "title": "Open", "open": true},
 {"black_hole": "Old trap", "threatens": ["K-1"]}]')
check "a black hole whose only threatened ticket is closed is left out of the drawing" \
  '! grep -q "Old trap\|H1" <<<"$closed" && grep -q "K-2" <<<"$closed"'

none=$(draw '[{"key": "K-1", "kind": "star", "title": "Build", "open": true}]')
check "a chart whose Black holes section reads \"None seen yet.\" has no black hole in its drawing" \
  '! grep -q "black hole\|blackhole" <<<"$none"'

warp=$(draw '[{"key": "K-1", "kind": "anomaly", "title": "Ask", "open": true},
 {"key": "K-2", "kind": "star", "title": "Build", "open": true, "blocked_by": ["K-1"]},
 {"black_hole": "Trap", "threatens": ["K-1"]}]' K-2)
check "a black hole drawn beside a frontier ticket during a warp is never marked as frontier or course" \
  'grep -q "^  class T1 frontier$" <<<"$warp" && ! grep -E "^  class .*H1.* (frontier|course)$" <<<"$warp" | grep -q .'

chart="$here/STAR-CHART.md"
check "a new chart's Black holes line names the tickets the black hole threatens, then its way around" \
  'grep -qF -- "- <the black hole>, threatening <links to the tickets it threatens>, and its way around:" "$chart" && grep -qF "\"black_hole\"" "$chart"'
exit $fail
