#!/usr/bin/env bash
# A decision a ticket records reaches the repo's docs: plot-twist starts when
# a ticket records a decision an earlier plan contradicts, and make-it-so's settling
# runs plot-twist's sweep for every ticket that records one.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/skills"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
desc() { awk '/^---$/{n++; next} n==1' "$1" | grep '^description:'; }
check "plot-twist's trigger names a decision a ticket records" 'desc "$root/productivity/plot-twist/SKILL.md" | grep -q "a ticket records a decision"'
check "settling runs plot-twist's sweep for a recorded decision" 'grep -q "records a decision.*plot-twist.*sweep" "$root/engineering/make-it-so/SETTLE.md"'
check "that sweep is part of settling step 2's Done when" 'grep -q "every decision a ticket records has had its sweep" "$root/engineering/make-it-so/SETTLE.md"'
exit $fail
