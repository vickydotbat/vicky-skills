#!/usr/bin/env bash
# Checks a star chart's Earlier attempts, as STAR-CHART.md's "Earlier attempts"
# says: the section exists, and holds either a bullet per attempt that opens
# with the link to the pull request, ticket or note that tried before, or one
# None found line that names where it searched and for what, never both. A
# prose line beside them, such as what this plan does differently, is free.
# Line ends and trailing blanks are ignored. Prints one line per problem,
# exits 1 on any. A repo whose agent docs read "Earlier attempts: off" is
# skipped: the chart's own repo when it sits in one, else the repo the command
# runs in.
set -u
[ $# -gt 0 ] || { echo "usage: check-earlier-attempts.sh <chart>..." >&2; exit 2; }
link='^- ([#!][0-9]+|[A-Z][A-Z0-9]+-[0-9]+|https?://[^[:space:]]+|\[\[[^]]+\]\]):'
none='^(- )?None found'
fail=0
for f in "$@"; do
  [ -r "$f" ] || { echo "$f: cannot read"; fail=1; continue; }
  root=$(git -C "$(dirname "$f")" rev-parse --show-toplevel 2>/dev/null || git rev-parse --show-toplevel 2>/dev/null)
  [ -n "$root" ] && grep -qsx 'Earlier attempts: off' "$root"/docs/agents/*.md && continue
  body=$(sed 's/[[:space:]]*$//' "$f")
  grep -qx '## Earlier attempts' <<<"$body" || { echo "$f: no ## Earlier attempts section: link each pull request or ticket that tried to fix this symptom, or write None found: searched <where> for <words>."; fail=1; continue; }
  lines=$(awk '$0 == "## Earlier attempts" {s=1; next} /^## /{s=0} s' <<<"$body" | grep -E '^(- |None found)')
  [ -n "$lines" ] || { echo "$f: Earlier attempts is empty: link each attempt, or write None found: searched <where> for <words>."; fail=1; continue; }
  if grep -qE "$none" <<<"$lines" && grep -vqE "$none" <<<"$lines"; then
    echo "$f: Earlier attempts says None found and lists attempts: keep one or the other, not both."; fail=1; continue
  fi
  while IFS= read -r line; do
    if [[ "$line" =~ $none ]]; then
      [[ "$line" =~ ^(-\ )?None\ found:\ searched\ .+\ for\ .+ ]] || { echo "$f: Earlier attempts says None found but names no search: write None found: searched <where> for <words>."; fail=1; }
    else
      [[ "$line" =~ $link ]] || { echo "$f: an earlier attempt links nothing: $line"; fail=1; }
    fi
  done <<<"$lines"
done
exit $fail
