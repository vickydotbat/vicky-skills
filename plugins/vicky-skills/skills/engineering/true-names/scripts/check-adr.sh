#!/usr/bin/env bash
# Checks decision records against ADR-FORMAT.md: a "# ADR-NNNN: " title, a
# "Decided YYYY-MM-DD." line and a "Because " line, once each and in that order,
# with no backticks and no other line. Prints one line per problem and exits 1
# when any record fails.
set -u
[ $# -gt 0 ] || { echo "usage: check-adr.sh <record>..." >&2; exit 2; }
fail=0
for f in "$@"; do
  [ -r "$f" ] || { echo "$f: cannot read"; fail=1; continue; }
  shape=$(grep -v '^[[:space:]]*$' "$f" | sed -E \
    -e 's/^# ADR-[0-9]{4}: .+/what/' \
    -e 's/^Decided [0-9]{4}-[0-9]{2}-[0-9]{2}\.$/when/' \
    -e 's/^Because .+/why/' | tr '\n' ' ')
  [ "$shape" = "what when why " ] || { echo "$f: needs exactly what, when, why; found: $shape"; fail=1; }
  grep -q '`' "$f" && { echo "$f: names code in backticks: that belongs in the code"; fail=1; }
done
exit $fail
