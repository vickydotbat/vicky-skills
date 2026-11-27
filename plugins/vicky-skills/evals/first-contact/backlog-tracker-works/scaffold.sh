#!/usr/bin/env bash
set -eu
git init -q -b main .
git remote add origin https://example.invalid/acme/widget.git
printf '# Widget\n\nRun the tests with: python3 -m unittest\n' > README.md
git add -A
git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
