#!/usr/bin/env bash
# Counts each frozen snag rule in shapes/*.jq over every transcript in a
# folder: hits per 100 user turns, per day, and before and after a law.
# Usage: familiar-shapes.sh <transcripts folder> [--law <shape>=<YYYY-MM-DD>]...
set -u
corpus=${1:?usage: familiar-shapes.sh <transcripts folder> [--law <shape>=<YYYY-MM-DD>]...}; shift
laws=()
while [ $# -gt 0 ]; do
  case $1 in --law) laws+=("${2:?--law needs <shape>=<YYYY-MM-DD>}"); shift 2 ;; *) echo "familiar-shapes: unknown argument $1" >&2; exit 2 ;; esac
done
rules=$(dirname "$0")/shapes
# A copy of familiar-watch.sh's USER rule: the watch prints times without a date, and a rate needs the day.
turns='.[] | select(.type == "user" and (.isMeta | not) and (.isCompactSummary | not))
  | select((.message.content | type) == "string") | select(.message.content | test("^<") | not)
  | select(.message.content | test("\\S")) | .timestamp[0:10]'
tally=$(mktemp); trap 'rm -f "$tally"' EXIT
while IFS= read -r t; do
  jq -e -s 'length >= 0' "$t" >/dev/null 2>&1 || { echo unreadable; continue; }
  jq -r -s '.[] | .timestamp? // empty | "day " + .[0:10]' "$t" 2>/dev/null
  jq -r -s "$turns" "$t" 2>/dev/null | sed 's/^/turn /'
  for r in "$rules"/*.jq; do
    jq -r -s -f "$r" "$t" 2>/dev/null | cut -c1-10 | sed "s/^/hit $(basename "$r" .jq) /"
  done
done < <(find "$corpus" -name '*.jsonl' -type f | sort) > "$tally"
shapes=$(for r in "$rules"/*.jq; do basename "$r" .jq; done)
awk -v shapes="$shapes" -v laws="${laws[*]}" '
  $1 == "day" { days[$2] = 1 } $1 == "turn" { turns[$2]++ } $1 == "hit" { hits[$2, $3]++ } $1 == "unreadable" { unreadable++ }
  END {
    n = split(shapes, s, "\n"); m = 0
    for (d in days) list[++m] = d
    for (i = 2; i <= m; i++) for (j = i; j > 1 && list[j - 1] > list[j]; j--) { x = list[j]; list[j] = list[j - 1]; list[j - 1] = x }
    for (i = 1; i <= m; i++) for (k = 1; k <= n; k++) {
      d = list[i]; h = hits[s[k], d] + 0
      if (turns[d] + 0 == 0) printf "%s %s no user turns, no rate\n", d, s[k]
      else printf "%s %s %d/%d turns = %.1f per 100\n", d, s[k], h, turns[d], 100 * h / turns[d]
    }
    if (unreadable) printf "unreadable transcripts, left out: %d\n", unreadable
    split(laws, l, " ")
    for (q in l) {
      split(l[q], kv, "="); bh = bt = ah = at = 0
      for (i = 1; i <= m; i++) { d = list[i]; if (d < kv[2]) { bh += hits[kv[1], d]; bt += turns[d] } else { ah += hits[kv[1], d]; at += turns[d] } }
      printf "%s law %s: before %s, after %s\n", kv[1], kv[2], bt ? sprintf("%.1f per 100", 100 * bh / bt) : "no rate", at ? sprintf("%.1f per 100", 100 * ah / at) : "no rate"
    }
  }' "$tally"
