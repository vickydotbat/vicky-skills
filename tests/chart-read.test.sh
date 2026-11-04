#!/usr/bin/env bash
# Every skill that reads a ticket whole also reads the star chart the ticket
# sits on, so a chart's Prime directive reaches every build, not only warp.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/skills"
fail=0
for f in $(grep -rlE "[Rr]ead (the ticket|each one|each target) whole, body and comments" "$root"); do
  if grep -q "Prime directive" "$f"; then echo "ok   ${f#"$root"/} reads the chart's Prime directive"
  else echo "FAIL ${f#"$root"/} reads a ticket whole but never its chart"; fail=1; fi
done
exit "$fail"
