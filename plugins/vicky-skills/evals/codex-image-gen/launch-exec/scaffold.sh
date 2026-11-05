#!/usr/bin/env bash
set -eu
git init -q -b main .
mkdir -p scratch out
touch scratch/.keep out/.keep
git add -A; git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
