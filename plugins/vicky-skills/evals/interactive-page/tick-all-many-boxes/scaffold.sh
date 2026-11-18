#!/usr/bin/env bash
set -eu
git init -q -b main .
{ echo '# Release checklist'; echo; echo '## Before'; for i in $(seq 1 12); do echo "- [ ] step $i"; done
  echo; echo '## After'; for i in $(seq 13 24); do echo "- [ ] step $i"; done; } > checklist.md
git add -A
git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
