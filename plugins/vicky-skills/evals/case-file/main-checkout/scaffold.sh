#!/usr/bin/env bash
# A repo whose effort runs in a linked worktree under .claude/worktrees/glow.
set -eu
git init -q -b main .
printf '.case-files/\n.claude/\n' > .gitignore
git add .gitignore && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
git worktree add -q -b glow .claude/worktrees/glow
