#!/usr/bin/env bash
# Checks a star chart's Earlier attempts, as STAR-CHART.md's "Earlier attempts"
# says: the section exists, and holds a bullet per attempt that links the pull
# request or ticket that tried before, or a None found line that names its
# search. A prose line beside them, such as what this plan does differently,
# is free. Prints one line per problem, exits 1 on any. A repo whose agent
# docs read "Earlier attempts: off" is skipped: the chart's own repo when it
# sits in one, else the repo the command runs in.
set -u
[ $# -gt 0 ] || { echo "usage: check-earlier-attempts.sh <chart>..." >&2; exit 2; }
link='(^|[^[:alnum:]])([#!][0-9]+|[A-Z][A-Z0-9]*-[0-9]+|https?://)'
fail=0
for f in "$@"; do
  [ -r "$f" ] || { echo "$f: cannot read"; fail=1; continue; }
  root=$(git -C "$(dirname "$f")" rev-parse --show-toplevel 2>/dev/null || git rev-parse --show-toplevel 2>/dev/null)
  [ -n "$root" ] && grep -qsx 'Earlier attempts: off' "$root"/docs/agents/*.md && continue
  grep -qx '## Earlier attempts' "$f" || { echo "$f: no ## Earlier attempts section: link each pull request or ticket that tried to fix this symptom, or write None found: searched <where> for <words>."; fail=1; continue; }
  lines=$(awk '$0 == "## Earlier attempts" {s=1; next} /^## /{s=0} s' "$f" | grep -E '^(- |None found)')
  [ -n "$lines" ] || { echo "$f: Earlier attempts is empty: link each attempt, or write None found: searched <where> for <words>."; fail=1; continue; }
  while IFS= read -r line; do
    if [[ "$line" == "None found"* ]]; then
      [[ "$line" =~ ^None\ found:\ .*search ]] || { echo "$f: Earlier attempts says None found but names no search: write None found: searched <where> for <words>."; fail=1; }
    else
      [[ "$line" =~ $link ]] || { echo "$f: an earlier attempt links nothing: $line"; fail=1; }
    fi
  done <<<"$lines"
done
exit $fail
