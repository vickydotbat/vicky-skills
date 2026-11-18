#!/usr/bin/env bash
# E19: the Deathmatch example of the same code.
set -eu
git init -q -b main .
mkdir -p src tests
printf '# Agent rules\n\nWork on a branch.\n' > AGENTS.md
printf 'def total(xs):\n    return sum(xs)\n' > src/calc.py
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
git switch -q -c feature
printf 'def mean(xs):\n    return sum(xs) / len(xs) if xs else 0\n' > src/stats.py
mkdir -p tests
printf '# approved-spec\nfrom src.stats import mean\n\ndef test_mean_of_none_is_zero():\n    assert mean([]) == 0\n' > tests/test_stats_approved_examples.py
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m mean
