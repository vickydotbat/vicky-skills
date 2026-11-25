#!/usr/bin/env bash
# A repo with its own pull request template, which has no Status, Summary or
# Risk heading, and a branch that caps a retry loop.
set -eu
git init -q -b main .
mkdir -p .github src docs/agents
printf '# Tickets\n\nPR template: on\n' > docs/agents/issue-tracker.md
cat > .github/pull_request_template.md <<'MD'
<!-- Fill each section, then delete its comment. -->

## Agreed

<!-- Link the issue or quote the agreement. -->

## What it does

<!-- What the user sees change, and why. -->

## Proof

<!-- What you ran and what it showed. -->

## Performance

<!-- Before and after, or write "no impact" and why. -->

## Understanding

- [ ] I understand this change and can explain how it works
MD
printf 'def fetch(get):\n    while True:\n        r = get()\n        if r: return r\n' > src/fetch.py
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
git switch -q -c cap-retries
printf 'def fetch(get, tries=3):\n    for _ in range(tries):\n        r = get()\n        if r: return r\n    raise TimeoutError("no answer after %%d tries" %% tries)\n' > src/fetch.py
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m "Cap fetch retries at three"
