#!/usr/bin/env bash
set -eu
git init -q -b main .
mkdir -p docs/agents tickets
cat > docs/agents/issue-tracker.md <<'MD'
# Issue tracker

Tickets are markdown files in `tickets/`, named `<number>-<slug>.md`, with a `Status: open` or `Status: closed` line first.

## Waiting work

Park a ticket: add a `Waits on: <who or what>` line to its body.
List waiting tickets: grep -l "Waits on:" tickets/*.md
MD
echo '# Reading list' > README.md
git add -A
git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
