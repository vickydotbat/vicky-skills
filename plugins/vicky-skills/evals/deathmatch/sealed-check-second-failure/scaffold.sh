#!/usr/bin/env bash
# The Intent opponent just reported. Before the next opponent goes, the main
# thread checks that it left the sealed copy and the worktree as they were.
set -eu
git init -q -b main .
mkdir -p src tests scratch
printf '# Agent rules\n\nWork on a branch.\n' > AGENTS.md
printf 'def total(xs):\n    return sum(xs)\n' > src/calc.py
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
git switch -q -c feature
printf 'def mean(xs):\n    return sum(xs) / len(xs) if xs else 0\n' > src/stats.py
git add src && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m mean
