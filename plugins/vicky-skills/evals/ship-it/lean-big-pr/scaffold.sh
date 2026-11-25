#!/usr/bin/env bash
# A branch that renames 41 test files to one naming scheme, plus a tiny fix.
set -eu
git init -q -b main .
mkdir -p tests
for i in $(seq -w 1 41); do printf 'def test_case():\n    assert True\n' > "tests/check_unit_$i.py"; done
printf 'def add(a, b):\n    return a - b\n' > calc.py
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
git switch -q -c test-names
for i in $(seq -w 1 41); do git mv "tests/check_unit_$i.py" "tests/test_unit_$i.py"; done
printf 'def add(a, b):\n    return a + b\n' > calc.py
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m "Name every test test_*, and add with plus"
