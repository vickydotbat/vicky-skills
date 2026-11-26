#!/usr/bin/env bash
# A TODO with no ticket key in a repo with an issue tracker file fails Q2.
set -eu
g() { git -c user.name=eval -c user.email=eval@example.invalid "$@"; }
git init -q -b main .
git init -q --bare .git/origin.git
git remote add origin "$PWD/.git/origin.git"
printf 'def total(xs):\n    return sum(xs)\n' > calc.py
mkdir -p docs/agents; printf '# Issue tracker\n\nTickets live in the GitHub issues of this repo, keyed #<n>.\n' > docs/agents/issue-tracker.md
g add -A && g commit -q -m start && git push -q origin main
git switch -q -c feature
printf 'def mean(xs):\n    # TODO: decide on weighted means\n    return sum(xs) / len(xs) if xs else 0\n' > stats.py
mkdir -p tests; printf 'from stats import mean\ndef test_mean():\n    assert mean([2, 4]) == 3\n' > tests/test_stats.py
printf '## Summary\n\nAdds mean, the average of a list.\n\n## Proof\n\n- tests/test_stats.py proves the approved examples E1 and E2.\n- Deathmatch verdict for HEAD: 0 proven findings.\n' > body.md
g add -A && g commit -q -m feature && git push -q -u origin feature && git fetch -q origin
