#!/usr/bin/env bash
set -eu
git init -q -b main .
mkdir -p docs/agents
cat > docs/agents/issue-tracker.md <<'MD'
# Issue tracker

Counts for "created or changed since" and "closed since" come from the user in chat.
MD
git add -A
git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
