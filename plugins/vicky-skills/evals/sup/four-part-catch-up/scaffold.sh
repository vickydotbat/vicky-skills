#!/usr/bin/env bash
set -eu
git init -q -b main .
echo '# app' > README.md
git add -A; git -c user.name=eval -c user.email=eval@example.invalid commit -q -m "Add readme"
echo 'v1' > app.txt
git add -A; git -c user.name=eval -c user.email=eval@example.invalid commit -q -m "Add app"
git add -A
git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
