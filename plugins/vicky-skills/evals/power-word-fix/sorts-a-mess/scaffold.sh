#!/usr/bin/env bash
set -eu
git init -q -b main .
echo hi > a.txt
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
git switch -q -c stale-one
git switch -q main
