#!/usr/bin/env bash
# A branch rebased onto an unrelated main commit, its body holding the old head's verdict.
set -eu
git init -q -b main .
printf 'def total(xs):\n    return sum(xs)\n' > calc.py
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
printf '## Proof\n\nDeathmatch verdict for 1a2b3c4: 0 proven findings\n' > body.md
