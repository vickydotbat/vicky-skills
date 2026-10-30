#!/usr/bin/env bash
# Checks decision records against ADR-FORMAT.md: a "# ADR-NNNN: " title, a
# "Decided YYYY-MM-DD." line and a "Because " line, once each and in that order,
# then an optional "Superseded by ADR-NNNN." line. No other line, no backticks,
# and at most 50 words. Prints one line per problem and exits 1 when any record
# fails.
set -u
[ $# -gt 0 ] || { echo "usage: check-adr.sh <record>..." >&2; exit 2; }
fail=0
for f in "$@"; do
  [ -r "$f" ] || { echo "$f: cannot read"; fail=1; continue; }
  shape=$(grep -v '^[[:space:]]*$' "$f" | sed -E \
    -e 's/^# ADR-[0-9]{4}: .+/what/' \
    -e 's/^Decided [0-9]{4}-[0-9]{2}-[0-9]{2}\.$/when/' \
    -e 's/^Because .+/why/' \
    -e 's/^Superseded by ADR-[0-9]{4}\.$/superseded/' | tr '\n' ' ')
  case "$shape" in
    "what when why "|"what when why superseded ") ;;
    *) echo "$f: needs what, when, why and nothing else; found: $shape"; fail=1 ;;
  esac
  grep -q '`' "$f" && { echo "$f: names code in backticks: that belongs in the code"; fail=1; }
  words=$(wc -w < "$f")
  [ "$words" -le 50 ] || { echo "$f: $words words, the limit is 50"; fail=1; }
done
exit $fail
