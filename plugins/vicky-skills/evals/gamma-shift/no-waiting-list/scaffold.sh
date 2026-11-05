#!/usr/bin/env bash
set -eu
git init -q -b main .
echo '# Repo with no agent docs' > README.md
git add -A
git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
