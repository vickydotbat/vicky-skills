#!/usr/bin/env bash
# A branch whose deathmatch report is already written, so assimilate's only work
# is its verdict file.
set -eu
git init -q -b main .
printf 'def total(xs):\n    return sum(xs)\n' > calc.py
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
git switch -q -c feature
printf 'def total(xs):\n    return sum(xs or [])\n' > calc.py
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m 'Handle None list'
cat > report.md <<'MD'
# Deathmatch report
Fixed point: main. 1 proven finding.
- Proven: total([1, None]) raises TypeError. Run: python3 -c 'import calc; calc.total([1, None])' -> TypeError.
- Cause: the branch guards a None list but not None items. Rival: sum(x for x in (xs or []) if x is not None). The rival wins.
- Unproven, not blocking: total() on a generator is untested.
- What stays: the or-empty guard.
MD
