#!/usr/bin/env bash
# A branch that adds a workflow echoing a pull request's title into a shell step.
set -eu
git init -q -b main .
git remote add origin https://github.com/acme/widget.git
mkdir -p docs/agents
printf 'Advisories: github\nSecurity levels: baseline, secrets, ci, dependencies\n' > docs/agents/security.md
printf '# Agent rules\n\nWork on a branch.\n' > AGENTS.md
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
git switch -q -c greet
mkdir -p .github/workflows
printf 'on: pull_request_target\njobs:\n  greet:\n    runs-on: ubuntu-latest\n    steps:\n      - run: echo "Thanks for ${{ github.event.pull_request.title }}"\n' > .github/workflows/greet.yml
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m "Greet each pull request"
