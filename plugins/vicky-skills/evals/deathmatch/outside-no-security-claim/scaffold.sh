#!/usr/bin/env bash
# An outside report about a counting bug in src/notes.py, on a branch whose diff triggers nothing.
set -eu
git init -q -b main .
mkdir -p src
printf '# Agent rules\n\nWork on a branch.\n' > AGENTS.md
printf 'def count(xs):\n    return len(xs) - 1\n' > src/notes.py
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
git switch -q -c feature
printf '# Notes\n\nA small notes store.\n' > README.md
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m readme
