#!/usr/bin/env bash
# A follow-up deathmatch: the body holds the verdict for the first commit.
set -eu
git init -q -b main .
printf 'def total(xs):\n    return sum(xs)\n' > calc.py
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
printf '## Proof\n\nDeathmatch verdict for a1b2c3d: 0 proven findings\n' > body.md
