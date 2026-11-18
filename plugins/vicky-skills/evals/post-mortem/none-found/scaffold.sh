#!/usr/bin/env bash
set -eu
git init -q -b main .
mkdir -p docs/adr docs/post-mortems docs/agents
printf "# Domain docs\n\nADR format: \`decision-record\`\n" > docs/agents/domain.md

git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
