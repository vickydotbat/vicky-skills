#!/usr/bin/env bash
# A small plugin repo: one skill, and no tests, hooks or eval suite.
set -eu
git init -q -b main .
mkdir -p .claude-plugin skills/greet
echo '{"name":"tiny","skills":["./skills/greet"]}' > .claude-plugin/plugin.json
cat > skills/greet/SKILL.md <<'MD'
---
name: greet
description: Greet the user. Use when the user says hello.
---
# Greet

1. Say hello to the user by name.
MD
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
