#!/usr/bin/env bash
set -eu
git init -q -b main .
cat > limit.py <<'PY'
def allowed(n):
    return n < 10
PY
cat > test_limit.py <<'PY'
from limit import allowed
assert allowed(3)
assert not allowed(50)
print("ok")
PY
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
git switch -q -c change
sed -i 's/< 10/< 10 /' limit.py
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
