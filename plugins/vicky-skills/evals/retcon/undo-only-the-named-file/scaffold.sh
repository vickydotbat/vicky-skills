#!/usr/bin/env bash
set -eu
git init -q -b main .
echo one > a.txt; echo one > b.txt
git add -A; git -c user.name=eval -c user.email=eval@example.invalid commit -q -m base
echo two >> a.txt; echo two >> b.txt
git add -A
git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
