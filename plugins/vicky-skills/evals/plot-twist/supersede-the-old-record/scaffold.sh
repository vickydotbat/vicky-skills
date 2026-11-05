#!/usr/bin/env bash
set -eu
git init -q -b main .
mkdir -p docs/adr
cat > docs/adr/0003-use-postgres.md <<'MD'
# 0003 Use Postgres

Status: accepted

We store notes in Postgres.
MD
cat > README.md <<'MD'
# Notes

Notes are stored in Postgres. See docs/adr/0003-use-postgres.md.
MD
git add -A
git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
