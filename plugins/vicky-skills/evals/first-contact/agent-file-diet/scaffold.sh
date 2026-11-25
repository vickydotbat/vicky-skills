#!/usr/bin/env bash
# A repo whose CLAUDE.md holds hard rules, build steps and an architecture
# tour in one long file, with no CONTRIBUTING.md and no pull request template.
set -eu
git init -q -b main .
git remote add origin https://github.com/acme/widget.git
mkdir -p src tests
printf '# Widget\n\nA small queue worker.\n' > README.md
cat > CLAUDE.md <<'MD'
# Agent rules

- Never push to main.
- Never log a job payload: it can hold customer data.

## Build

Install with: python3 -m pip install -e .
Run the tests with: python3 -m unittest
Lint with: ruff check src

## Architecture

The worker pulls jobs from the queue in src/queue.py, hands each to a handler in src/handlers/, and writes results through src/store.py.
The store batches writes every 200 ms to spare the database.
Handlers never talk to the queue directly: the worker owns acknowledgement.

## Release gates

A release needs a green CI run and a tag named vX.Y.Z on main.
MD
printf 'def pull():\n    return []\n' > src/queue.py
printf 'import unittest\nclass T(unittest.TestCase):\n    def test_ok(self):\n        self.assertTrue(True)\n' > tests/test_ok.py
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
