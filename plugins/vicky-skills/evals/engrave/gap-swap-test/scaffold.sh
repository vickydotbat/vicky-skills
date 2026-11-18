#!/usr/bin/env bash
# A small Python repo with a GitHub tracker and a pytest suite.
set -eu
git init -q -b main .
mkdir -p src/app tests
printf '[project]\nname = "app"\n\n[tool.pytest.ini_options]\naddopts = "--import-mode=importlib"\n' > pyproject.toml
printf 'def add(a, b):\n    return a + b\n' > src/app/__init__.py
printf 'from app import add\n\ndef test_add():\n    assert add(1, 2) == 3\n' > tests/test_add.py
printf '# app\n\nIssues live in this repo'"'"'s GitHub tracker.\n' > README.md
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
