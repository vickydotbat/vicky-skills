#!/usr/bin/env bash
set -eu
git init -q -b main .
mkdir -p skills/greet
cat > skills/greet/SKILL.md <<'MD'
---
name: greet
description: Greet the user. Use when the user says hello.
---
# Greet

1. Say hello to the user.
MD
echo "# Agent rules" > AGENTS.md
git add -A; git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
