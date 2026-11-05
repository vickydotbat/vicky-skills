#!/usr/bin/env bash
set -eu
git init -q -b main .
cat > pr-body.md <<'MD'
## Status

`Done:` the settings page saves the theme.
`Next:` mark ready.
`Waits on:` nobody

## Check these

- Should the README be rewritten now, to describe the new theme setting? Answer taken: not now (commit 1a2b3c4).

## Risk

- Undo: a revert undoes it.
MD
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
