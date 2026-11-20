#!/usr/bin/env bash
# One ticket waits on the user's decision and nothing is cleared, so the shift
# builds no batch and asks the one question.
set -eu
git init -q -b main .
git remote add origin https://example.invalid/r.git
mkdir -p docs/agents tickets
cat > docs/agents/issue-tracker.md <<'T'
# Tickets: local

Tickets are Markdown files in `tickets/`.

## Waiting work

- **List waiting tickets**: `grep -l '^Waits on:' tickets/*.md`
T
cat > tickets/T-1.md <<'T'
# T-1 Greet a missing name

Waits on: you, to pick: ask for the name, or greet without one.

The greet command gets no name. Option A asks for it. Option B says "Hello" alone.
T
