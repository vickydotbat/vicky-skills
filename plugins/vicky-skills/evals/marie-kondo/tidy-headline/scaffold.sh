#!/usr/bin/env bash
set -eu
git init -q -b main .
echo hi > a.txt
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
git switch -q -c old-feature
echo x > b.txt
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
git switch -q main
git switch -q -c wip-idea
echo y > c.txt
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
git switch -q main
