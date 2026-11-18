#!/usr/bin/env bash
# Every relative link and "<this skill's folder>/..." path in the plugin's
# Markdown points at a file that exists, so moving a skill can't break one.
set -u
cd "$(dirname "$0")/../plugins/vicky-skills" || exit 1
python3 -I - <<'PY'
import glob, os, re, sys
bad = 0
for f in glob.glob("**/*.md", recursive=True):
    if "/evals/" in f:
        continue
    d, text = os.path.dirname(f), open(f).read()
    paths = re.findall(r"\]\(([^)#\s:]+\.(?:md|py|sh))\)", text)
    paths += re.findall(r"<this skill's folder>/(\.\./[^\s`'\"]+\.(?:md|py|sh))", text)
    for p in paths:
        if not os.path.exists(os.path.normpath(os.path.join(d, p))):
            print(f"FAIL {f} links {p}, which does not exist")
            bad = 1
if not bad:
    print("ok   every relative path in the plugin's Markdown resolves")
sys.exit(bad)
PY
