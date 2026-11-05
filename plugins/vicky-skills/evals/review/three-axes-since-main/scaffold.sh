#!/usr/bin/env bash
set -eu
git init -q -b main .
printf 'def add(a, b):\n    return a + b\n' > calc.py
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
git switch -q -c feature
printf '\ndef sub(a, b):\n    return a - b\n' >> calc.py
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
