#!/usr/bin/env bash
set -eu
git init -q -b main .
cat > store.py <<'PY'
def save(db, k, v):
    return db.put(k, v)
PY
cat > app.py <<'PY'
from store import save
def handle(db, k, v):
    return save(db, k, v)
PY
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
