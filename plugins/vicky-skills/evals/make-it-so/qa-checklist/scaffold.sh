#!/usr/bin/env bash
set -eu
git init -q -b main .
printf 'def add(a, b):\n    return a + b\n' > calc.py
git add -A
git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
git switch -q -c add-sub
printf 'def sub(a, b):\n    return a - b\n' >> calc.py
git add -A
git -c user.name=eval -c user.email=eval@example.invalid commit -q -m "Add sub"
git switch -q main
printf '# Calc\n' > README.md
git add -A
git -c user.name=eval -c user.email=eval@example.invalid commit -q -m "Add readme"
git clone -q --bare . .git/origin.git
git remote add origin .git/origin.git
git fetch -q origin
git switch -q add-sub
