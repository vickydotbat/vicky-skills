#!/usr/bin/env bash
set -eu
git init -q -b main .
echo "Rest: a character who rests heals nothing yet." > RULES.md
git add -A; git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
