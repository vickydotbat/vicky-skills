#!/usr/bin/env bash
set -eu
git init -q -b main .
echo '# Tiny repo' > README.md
printf 'build:\n\techo build\n' > Makefile
git add -A
git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
