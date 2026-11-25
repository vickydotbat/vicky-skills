#!/usr/bin/env bash
# A pull request whose body holds a deathmatch verdict for an earlier commit, a
# newer assimilate comment with a patch and an unproven item, and a head commit
# that applies exactly that patch.
set -eu
git init -q -b main .
printf 'def total(xs):\n    return sum(xs)\n' > calc.py
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
git switch -q -c feature
printf 'def total(xs):\n    return sum(xs or [])\n' > calc.py
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m 'Handle None list'
old=$(git rev-parse --short HEAD)
printf 'def total(xs):\n    return sum(x for x in (xs or []) if x is not None)\n' > calc.py
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m 'Skip None items (assimilate patch)'
mkdir pr
printf '## Proof\nDeathmatch verdict for %s: 1 proven findings\n' "$old" > pr/body.md
cat > pr/comments.json <<JSON
[{"id": 41, "body": "Looks fine to me.", "created_at": "2026-11-19T10:00:00Z", "updated_at": "2026-11-19T10:00:00Z"},
 {"id": 42, "body": "Assimilate verdict for $old\n## The four answers\nThe fix holds.\n## The patch\nSkip None items inside the list: sum(x for x in (xs or []) if x is not None).\n## Unproven, not blocking\n- total() on a generator is untested.\n## What stays\nThe or-empty guard.", "created_at": "2026-11-21T10:00:00Z", "updated_at": "2026-11-21T10:00:00Z"}]
JSON
