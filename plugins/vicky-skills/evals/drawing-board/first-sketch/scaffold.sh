#!/usr/bin/env bash
set -eu
git init -q -b main .
cat > inventory.py <<'PY'
WINDOW = (640, 480)
GRID = {"x": 16, "y": 40, "cols": 8, "rows": 5, "cell": 32}
CLOSE_BUTTON = {"x": 560, "y": 440, "w": 64, "h": 24, "label": "Close"}
PY
git add -A; git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
