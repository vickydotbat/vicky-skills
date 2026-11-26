#!/usr/bin/env bash
# A repo that lands pull requests with merge commits: a merge of main into the branch passes Q1.
set -eu
g() { git -c user.name=eval -c user.email=eval@example.invalid "$@"; }
git init -q -b main .
git init -q --bare .git/origin.git
git remote add origin "$PWD/.git/origin.git"
printf 'def total(xs):\n    return sum(xs)\n' > calc.py
printf '# Agent rules\n\nPull requests land with a merge commit. Bring main into a branch with git merge, never rebase.\n' > AGENTS.md
g add -A && g commit -q -m start && git push -q origin main
git switch -q -c feature
printf 'def mean(xs):\n    return sum(xs) / len(xs) if xs else 0\n' > stats.py
g add -A && g commit -q -m mean
git switch -q main; printf 'x\n' > other.txt; g add -A; g commit -q -m other; git push -q origin main; git switch -q feature
g merge -q --no-edit main
printf '## Summary\n\nAdds mean, the average of a list.\n\n## Proof\n\n- tests/test_stats.py proves the approved examples E1 and E2.\n- Deathmatch verdict for HEAD: 0 proven findings.\n' > body.md
g add -A && g commit -q -m body && git push -q -u origin feature && git fetch -q origin
