#!/usr/bin/env bash
# lay-course draws a chart from its tickets, so no agent writes the Mermaid by
# hand. A blocker draws an edge, an open blocker elsewhere is a node of its
# own, a ticket with no edge stacks in its kind's column, a closed ticket is
# left out, and the frontier and the course get their classes. A star's premise
# counts show in its label, a missing count as 0, and an unknown keeps it off
# the frontier.
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
# A star with one premise count set shows the other as 0.
echo '[{"key": "K-7", "kind": "star", "title": "Half", "open": true, "unknown": 2},
 {"key": "K-8", "kind": "star", "title": "Other", "open": true, "known": 1}]' > "$tickets"
out=$(python3 "$script" "$tickets")
expect "K-7 star: Half (0 known, 2 unknown)"
expect "K-8 star: Other (1 known, 0 unknown)"
expect "  class T2 frontier"
[ $fail -eq 0 ] && echo "ok   draw-chart builds edges, columns and classes from the tickets"
# The whole drawing for a small chart: a title's spaces fold, unlinked tickets stack in their kind's column.
cat > "$tickets" <<'JSON'
[{"key": "K-1", "kind": "task", "title": "Tidy\n   the   desk", "open": true},
 {"key": "K-2", "kind": "task", "title": "Sweep", "open": true},
 {"key": "K-3", "kind": "star", "title": "Build", "open": true, "blocked_by": ["K-4"]},
 {"key": "K-4", "kind": "star", "title": "Plan", "open": true}]
JSON
want='flowchart TD
  T3["K-3 star: Build"]
  T4["K-4 star: Plan"]
  subgraph C3["task"]
    direction TB
    T1["K-1 task: Tidy the desk"]
    T2["K-2 task: Sweep"]
    T1 ~~~ T2
  end
  T4 --> T3
  classDef frontier stroke-width:3px
  classDef course fill:#fde68a
  class T1,T2,T4 frontier'
[ "$(python3 "$script" "$tickets")" = "$want" ] || { echo "FAIL the whole drawing for a small chart"; fail=1; }
# --png renders through mmdc at the drawing's own width. A stub mmdc stands in.
bin=$(mktemp -d); trap 'rm -f "$tickets"; rm -rf "$bin"' EXIT
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$@" > "%s/args"; while [ $# -gt 0 ]; do case $1 in -c) cp "$2" "%s/config";; -i) cp "$2" "%s/source";; esac; shift; done; exit ${MMDC_EXIT:-0}\n' "$bin" "$bin" "$bin" > "$bin/mmdc"; chmod +x "$bin/mmdc"
out=$(PATH="$bin:$PATH" python3 "$script" "$tickets" --png "$bin/c.svg"); code=$?
[ $code = 0 ] && [ "$out" = "$want" ] || { echo "FAIL --png still prints the drawing"; fail=1; }
grep -qx -- "-o" "$bin/args" && grep -qx "$bin/c.svg" "$bin/args" || { echo "FAIL --png names its output to mmdc"; fail=1; }
[ "$(cat "$bin/config")" = '{"flowchart": {"useMaxWidth": false}}' ] || { echo "FAIL mmdc draws at the drawing's own width"; fail=1; }
[ "$(cat "$bin/source")" = "$want" ] || { echo "FAIL mmdc gets the drawing"; fail=1; }
err=$(MMDC_EXIT=1 PATH="$bin:$PATH" python3 "$script" "$tickets" --png "$bin/c.svg" 2>&1 >/dev/null); code=$?
[ $code = 1 ] && grep -q "^draw-chart: mmdc failed" <<<"$err" || { echo "FAIL a failed render says so"; fail=1; }
mkdir "$bin/bare"; ln -s "$(command -v python3)" "$bin/bare/python3"
err=$(PATH="$bin/bare" python3 "$script" "$tickets" --png "$bin/c.svg" 2>&1 >/dev/null); code=$?
[ $code = 1 ] && [ "$err" = "draw-chart: install mermaid-cli (mmdc) to render a PNG" ] || { echo "FAIL no mmdc, nix or npx says what to install"; fail=1; }
[ "$(python3 "$script" 2>&1)" = "Usage: draw-chart.py <tickets.json> [--course KEY,KEY] [--png <chart.png or chart.svg>]" ] || { echo "FAIL a wrong call prints the usage"; fail=1; }
exit $fail
