#!/usr/bin/env bash
# A GitHub-hosted repo on every security level, with no SECURITY.md yet.
set -eu
git init -q -b main .
git remote add origin https://github.com/acme/widget.git
mkdir -p docs/agents
printf 'Advisories: github\nSecurity levels: baseline, secrets, ci, dependencies\n' > docs/agents/security.md
printf '# Agent rules\n\nWork on a branch.\n' > AGENTS.md
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
