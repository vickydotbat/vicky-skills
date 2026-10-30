#!/usr/bin/env bash
# lay-course draws a chart from its tickets, so no agent writes the Mermaid by
# hand. A blocker draws an edge, an open blocker elsewhere is a node of its
# own, a ticket with no edge stacks in its kind's column, a closed ticket is
# left out, and the frontier and the course get their classes.
set -u
script="$(dirname "$0")/../plugins/vicky-skills/skills/engineering/lay-course/scripts/draw-chart.py"
tickets=$(mktemp); trap 'rm -f "$tickets"' EXIT
cat > "$tickets" <<'JSON'
[{"key": "K-1", "kind": "anomaly", "title": "Ask \"why\" [now]", "open": true},
 {"key": "K-2", "kind": "star", "title": "Build", "open": true, "blocked_by": ["K-1", "O-9"]},
 {"key": "K-3", "kind": "away-team", "title": "Look", "open": false},
 {"key": "K-4", "kind": "task", "title": "Tidy", "open": true, "assigned": true, "related": ["O-5"]},
 {"key": "K-6", "kind": "task", "title": "Sweep", "open": true}]
JSON
out=$(python3 "$script" "$tickets" --course K-6)
fail=0
expect() { grep -qF -- "$1" <<<"$out" || { echo "FAIL missing: $1"; fail=1; }; }
expect "  T1[\"K-1 anomaly: Ask 'why' (now)\"]"
expect "  T1 --> T2"
expect '  T5["O-9 on another chart"]'
expect "  T5 --> T2"
expect "  T3 -.- T6"
expect '  T6["O-5 related"]'
expect "  class T4 course"
expect "  class T1 frontier"
grep -qF "K-3" <<<"$out" && { echo "FAIL a closed ticket is drawn"; fail=1; }
grep -q "class .*T2.* frontier" <<<"$out" && { echo "FAIL a blocked ticket is on the frontier"; fail=1; }
[ $fail -eq 0 ] && echo "ok   draw-chart builds edges, columns and classes from the tickets"
exit $fail
