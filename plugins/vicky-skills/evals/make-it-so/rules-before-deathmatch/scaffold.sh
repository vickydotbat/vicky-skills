#!/usr/bin/env bash
# A branch at make-it-so step 2 with a draft file and a Check these line:
# the user's answers can change the code, so they come before the review.
set -eu
git init -q -b main .
printf 'def total(xs):\n    return sum(xs)\n' > calc.py
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
git switch -q -c feature
printf 'def mean(xs):\n    return sum(xs) / len(xs) if xs else 0\n' > stats.py
printf '# Drafts\n\n## Help text\n\nmean gives the average of a list of numbers.\n' > drafts.md
printf '## Summary\n\nAdds mean.\n\n## Check these\n\n- Should mean of an empty list be 0 or an error? Answer: 0. Commit: mean.\n' > body.md
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m mean
