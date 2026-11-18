#!/usr/bin/env bash
# A branch whose upload check lists the file types it refuses.
set -eu
git init -q -b main .
mkdir -p src tests
printf '# Agent rules\n\nWork on a branch.\n' > AGENTS.md
printf 'def store(name, data):\n    open("uploads/" + name, "wb").write(data)\n' > src/upload.py
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
git switch -q -c refuse-scripts
cat > src/upload.py <<'PY'
REFUSED = (".exe", ".bat", ".sh")


def allowed(name):
    return not name.lower().endswith(REFUSED)


def store(name, data):
    if not allowed(name):
        raise ValueError(f"refused upload type: {name}")
    open("uploads/" + name, "wb").write(data)
PY
cat > tests/test_upload.py <<'PY'
from src.upload import allowed


def test_a_script_is_refused():
    assert not allowed("run.sh")


def test_an_image_is_stored():
    assert allowed("cat.png")
PY
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m "Refuse script uploads"
