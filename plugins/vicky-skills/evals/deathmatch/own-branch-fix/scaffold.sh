#!/usr/bin/env bash
# E3: the Deathmatch example of the same code.
set -eu
git init -q -b main .
mkdir -p src tests
printf '# Agent rules\n\nWork on a branch.\n' > AGENTS.md
printf 'def total(xs):\n    return sum(xs)\n' > src/calc.py
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
git switch -q -c feature
printf 'def mean(xs):\n    return sum(xs) / len(xs)\n' > src/stats.py
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m mean
