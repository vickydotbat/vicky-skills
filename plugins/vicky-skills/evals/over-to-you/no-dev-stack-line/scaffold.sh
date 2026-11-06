#!/usr/bin/env bash
set -eu
git init -q -b main .
mkdir -p docs/agents
printf 'Drop worktree: scripts/drop-worktree.sh\n' > docs/agents/testing.md
printf '<img src="logo.png" alt="Logo">\n' > login.html
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
git worktree add -q -b logo-fix .claude/worktrees/logo-fix
