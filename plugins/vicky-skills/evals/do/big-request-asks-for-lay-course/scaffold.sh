#!/usr/bin/env bash
# An empty repo with one commit, for a request too big for one session.
set -eu
git init -q -b main .
printf '# shop\n' > README.md
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
