#!/usr/bin/env bash
# A TODO with no ticket key in a repo with no issue tracker file passes Q2.
set -eu
g() { git -c user.name=eval -c user.email=eval@example.invalid "$@"; }
git init -q -b main .
git init -q --bare .git/origin.git
git remote add origin "$PWD/.git/origin.git"
echo body.md >> .git/info/exclude
printf 'def total(xs):\n    return sum(xs)\n' > calc.py
g add -A && g commit -q -m start && git push -q origin main
git switch -q -c feature
printf 'def mean(xs):\n    # TODO: decide on weighted means\n    return sum(xs) / len(xs) if xs else 0\n' > stats.py
mkdir -p tests; printf 'from stats import mean\ndef test_mean():\n    assert mean([2, 4]) == 3\n' > tests/test_stats.py
printf '## Summary\n\nAdds mean, the average of a list.\n\n## Proof\n\n- tests/test_stats.py proves the approved examples E1 and E2.\n- Deathmatch verdict for HEAD: 0 proven findings.\n' > body.md
g add -A && g commit -q -m feature && git push -q -u origin feature && git fetch -q origin
