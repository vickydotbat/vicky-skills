#!/usr/bin/env bash
# approved-spec: the examples approved on the star "A star's readiness counts
# its open unknowns". Each check is named after its example.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
cd "$here/../plugins/vicky-skills/skills/engineering"
chart=lay-course/STAR-CHART.md
draw=lay-course/scripts/draw-chart.py
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
tickets=$(mktemp); trap 'rm -f "$tickets"' EXIT
cat > "$tickets" <<'JSON'
[{"key": "K-1", "kind": "star", "title": "Ready", "open": true, "known": 3, "unknown": 0},
 {"key": "K-2", "kind": "star", "title": "Waits", "open": true, "known": 2, "unknown": 1},
 {"key": "K-3", "kind": "star", "title": "Plain", "open": true}]
JSON
out=$(python3 "$draw" "$tickets")
frontier=$(grep -E "^  class .* frontier$" <<<"$out")

# Given a star with an open known unknown or unconfirmed unknown known behind it
# When lay-course or warp picks the next star
# Then that star is not on the frontier
check "a star with an open known unknown or unconfirmed unknown known behind it is not on the frontier when lay-course or warp picks" \
  'grep -q "T1" <<<"$frontier" && ! grep -q "T2" <<<"$frontier" && grep -q "T3" <<<"$frontier" \
   && grep -E "^\| \*\*frontier\*\* \|" "$chart" | grep -q "Knowns" \
   && grep -q "Knowns" warp/SKILL.md && grep -E "^2\. \*\*Pick the ticket" lay-course/SKILL.md | grep -q "Knowns"'
# Given a star chart
# When you ask for its course
# Then each star shows how many of its premises are known knowns and how many are still unknown
check "each star in a chart's course shows how many of its premises are known knowns and how many are still unknown" \
  'grep -qF "K-2 star: Waits (2 known, 1 unknown)" <<<"$out" && grep -qF "K-1 star: Ready (3 known, 0 unknown)" <<<"$out" \
   && grep -qF "K-3 star: Plain\"" <<<"$out" \
   && grep -q "\"known\"" "$chart" && grep -E "^3\. \*\*Light the course" warp/SKILL.md | grep -q "unknown"'
exit $fail
