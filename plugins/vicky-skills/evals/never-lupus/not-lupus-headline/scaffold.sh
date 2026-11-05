#!/usr/bin/env bash
set -eu
git init -q -b main .
cat > total.py <<'PY'
def total(prices):
    s = 0
    for i in range(1, len(prices)):
        s += prices[i]
    return s
PY
cat > test_total.py <<'PY'
from total import total
assert total([5, 10, 20]) == 35, total([5, 10, 20])
print("ok")
PY
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
