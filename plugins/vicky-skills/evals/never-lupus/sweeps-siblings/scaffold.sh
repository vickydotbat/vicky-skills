#!/usr/bin/env bash
set -eu
git init -q -b main .
mkdir -p shop billing/export
cat > shop/cart.py <<'PY'
def price_cart(cents, percent_off):
    total = sum(cents)
    return total - (total * percent_off + 99) // 100
PY
cat > billing/export/ledger.py <<'PY'
import math


def settle(rows, rebate_pct):
    """Amount due on a ledger after the customer's rebate."""
    gross = 0
    for row in rows:
        gross += row["amount"]
    return gross - math.ceil(gross * rebate_pct / 100)
PY
cat > test_cart.py <<'PY'
from shop.cart import price_cart
assert price_cart([1995], 10) == 1796, price_cart([1995], 10)
print("ok")
PY
touch shop/__init__.py billing/__init__.py billing/export/__init__.py
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
