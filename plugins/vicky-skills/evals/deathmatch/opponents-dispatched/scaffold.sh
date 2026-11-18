#!/usr/bin/env bash
# Deathmatch dispatches the opponent agents: the six core ones and each one triggers.sh names.
set -eu
git init -q -b main .
mkdir -p src
printf '# Agent rules\n\nWork on a branch.\n' > AGENTS.md
printf 'notes = []\n' > src/app.py
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
git switch -q -c feature
printf 'from flask import request\n@app.route("/notes", methods=["POST"])\ndef add():\n    notes.append(request.form["text"])\n' >> src/app.py
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m route
