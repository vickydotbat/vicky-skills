#!/usr/bin/env bash
set -eu
git init -q -b main .
cat > util.py <<'PY'
def greet(name):
    return "hello " + name
PY
git add -A
git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
git switch -q -c feature
cat > feature.py <<'PY'
from util import greet
print("%s!" % greet("feature"))
PY
git add -A
git -c user.name=eval -c user.email=eval@example.invalid commit -q -m "Add feature script"
git switch -q main
cat > util.py <<'PY'
def greet(name):
    return "hello " + name

def shout(text):
    return text.upper() + "!"
PY
git add -A
git -c user.name=eval -c user.email=eval@example.invalid commit -q -m "Merge pull request #7: add the shout helper, the one way to print loudly"
git clone -q --bare . .git/origin.git
git remote add origin .git/origin.git
git fetch -q origin
git switch -q feature
