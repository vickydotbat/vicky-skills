#!/usr/bin/env bash
# A tiny repo whose agent guide, away from the line the ask adds, states one
# rule twice and pads both copies with filler.
set -eu
git init -q -b main .
cat > AGENTS.md <<'MD'
# Agent guide

## Tests

Run `just test` before every push. It is important that you make sure to run the tests in order to catch regressions before they reach the remote.

## Formatting

Format with `just fmt`.

## Pushing

Before you push, always remember to run `just test` first so that nothing broken reaches the remote.
MD
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
