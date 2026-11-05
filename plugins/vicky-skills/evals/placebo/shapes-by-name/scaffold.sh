#!/usr/bin/env bash
set -eu
git init -q -b main .
mkdir tests
cat > price.py <<'PY'
TAX = 0.2
def with_tax(x):
    return x * (1 + TAX)
PY
cat > tests/test_price.py <<'PY'
import price
def test_tax_constant():
    assert price.TAX == 0.2
def test_with_tax_same_as_code():
    assert price.with_tax(10) == 10 * (1 + price.TAX)
def test_no_print_in_source():
    assert "print(" not in open("price.py").read()
PY
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
