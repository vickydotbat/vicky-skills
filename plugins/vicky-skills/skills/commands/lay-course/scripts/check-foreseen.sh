#!/usr/bin/env bash
# Checks a star chart's pre-mortem, as STAR-CHART.md's "Sorting the knowns"
# says: each Foreseen line is dated and has a disposition, or the chart holds a
# None foreseen line with its reason. Prints one line per problem, exits 1 on
# any. A repo whose agent docs read "Pre-mortems: off" is skipped: the chart's
# own repo when it sits in one, else the repo the command runs in.
set -u
[ $# -gt 0 ] || { echo "usage: check-foreseen.sh <chart>..." >&2; exit 2; }
fail=0
for f in "$@"; do
  [ -r "$f" ] || { echo "$f: cannot read"; fail=1; continue; }
  root=$(git -C "$(dirname "$f")" rev-parse --show-toplevel 2>/dev/null || git rev-parse --show-toplevel 2>/dev/null)
  [ -n "$root" ] && grep -qsx 'Pre-mortems: off' "$root"/docs/agents/*.md && continue
  foreseen=$(grep -E '^- Foreseen' "$f")
  if [ -z "$foreseen" ]; then
    grep -qE '^- None foreseen: .' "$f" || { echo "$f: no pre-mortem: add a Foreseen line per foreseen failure, or None foreseen: <reason>"; fail=1; }
    continue
  fi
  while IFS= read -r line; do
    [[ "$line" =~ ^-\ Foreseen\ [0-9]{4}-[0-9]{2}-[0-9]{2}:\ . ]] || { echo "$f: a Foreseen line has no date: $line"; fail=1; continue; }
    [[ "$line" =~ ,\ (guarded\ by\ .|accepted|ticketed) ]] || { echo "$f: a foreseen failure has no disposition (guarded by, accepted or ticketed): ${line#*: }"; fail=1; }
  done <<<"$foreseen"
done
exit $fail
