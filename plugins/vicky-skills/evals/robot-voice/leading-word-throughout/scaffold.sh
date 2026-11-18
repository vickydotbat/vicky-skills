#!/usr/bin/env bash
# A tiny repo whose agent guide names a law by a sentence, pads it with
# filler, and cites it again later by a paraphrase.
set -eu
git init -q -b main .
cat > AGENTS.md <<'MD'
# Agent guide

## Every schema change ships its migration

Make sure to always put the migration in the same pull request as the schema change, in order to keep every build bootable.

## Reviews

When reviewing, it is important that you check each table change comes with the script that updates the database.
MD
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
