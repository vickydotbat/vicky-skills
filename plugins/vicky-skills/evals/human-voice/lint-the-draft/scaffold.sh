#!/usr/bin/env bash
set -eu
git init -q -b main .
cat > CHANGES.md <<'MD'
The retry loop in sync.py now waits twice as long after each failure, up to 60 seconds.
Before, it retried every second and hammered the server during an outage.
MD
git add -A; git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
