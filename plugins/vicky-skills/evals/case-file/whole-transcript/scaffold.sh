#!/usr/bin/env bash
# Two saved sessions. Session 7f3a found the cause early, then was compacted:
# only the saved transcript still holds the early finding.
set -eu
git init -q -b main .
printf '.case-files/\n' > .gitignore
mkdir -p sessions
cat > sessions/7f3a.jsonl <<'J'
{"type":"user","timestamp":"2026-11-18T19:00:00Z","message":{"role":"user","content":"Why does the lantern not glow?"}}
{"type":"assistant","timestamp":"2026-11-18T19:20:00Z","message":{"role":"assistant","content":[{"type":"text","text":"Found it: the lantern material named the wrong texture, so the glow map never bound."}]}}
{"type":"system","subtype":"compact_boundary","timestamp":"2026-11-18T20:00:00Z"}
{"type":"user","isCompactSummary":true,"timestamp":"2026-11-18T20:00:01Z","message":{"role":"user","content":"Summary: lantern glow work."}}
{"type":"assistant","timestamp":"2026-11-18T20:40:00Z","message":{"role":"assistant","content":[{"type":"text","text":"The lantern glowed warm at night after the fix, run 1."}]}}
J
cat > sessions/9b21.jsonl <<'J'
{"type":"user","timestamp":"2026-11-17T10:00:00Z","message":{"role":"user","content":"Tidy the README."}}
J
git add .gitignore && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
