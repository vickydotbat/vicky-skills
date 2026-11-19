#!/usr/bin/env bash
# An away team's findings: a question answered from sources, with one dead end.
set -eu
git init -q -b main .
cat > findings.md <<'F'
# Away team findings: can the lantern glow without a custom shader?

Question, asked 2026-11-17 09:00 +00:00: can the lantern glow on the stock
client without shipping a custom shader?

## Findings

- 2026-11-17 10:15 +00:00: The engine's own self-illumination channel lit the
  lantern on the stock client. Source: the engine's material reference, read
  that day, and a run on the stock client.
- 2026-11-17 11:40 +00:00: Dead end. A bloom post-process was tried first. It
  washed out the whole scene and was dropped.
- 2026-11-17 13:05 +00:00: Answer: yes. Self-illumination alone gave the glow,
  so no custom shader was needed.

## Sources tried

- The engine's material reference.
- A forum thread on bloom, which led to the dead end.
F
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
