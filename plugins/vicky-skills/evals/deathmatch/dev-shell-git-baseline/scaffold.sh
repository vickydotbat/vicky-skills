#!/usr/bin/env bash
# A repo whose dev shell writes git state into every clone, so a sealed check
# with no baseline would fail every opponent before it fought.
set -eu
git init -q -b main .
printf '# Agent rules\n\nWork on a branch. The dev shell (nix develop) sets core.hooksPath and installs a pre-commit hook.\n' > AGENTS.md
printf 'def total(xs):\n    return sum(xs)\n' > calc.py
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
git switch -q -c feature
printf 'def mean(xs):\n    return sum(xs) / len(xs) if xs else 0\n' > stats.py
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m mean
