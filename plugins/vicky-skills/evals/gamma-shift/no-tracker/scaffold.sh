#!/usr/bin/env bash
# A repo with a remote and no tracker file: gamma-shift has nothing to list.
set -eu
git init -q -b main .
git remote add origin https://example.invalid/r.git
printf '# Demo\n' > README.md
