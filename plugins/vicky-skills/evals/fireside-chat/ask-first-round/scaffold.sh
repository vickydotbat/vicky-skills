#!/usr/bin/env bash
set -eu
git init -q -b main .
echo "def sync(): pass" > sync.py
git add -A; git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
echo "retry with backoff, up to 60 seconds" >> sync.py
git add -A; git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
