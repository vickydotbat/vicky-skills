#!/usr/bin/env bash
set -eu
git init -q -b main .
git remote add origin https://git.example.invalid/acme/widget.git
mkdir -p .gitea/workflows docs
cat > .gitea/workflows/ci.yml <<'YML'
name: ci
on:
  pull_request:
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: make build
YML
echo '# docs' > docs/index.md
git add -A
git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
