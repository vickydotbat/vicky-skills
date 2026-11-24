#!/usr/bin/env bash
# A small plugin repo: a pitch skill, with an eval suite that has no case for it yet.
set -eu
git init -q -b main .
mkdir -p .claude-plugin skills/pitch evals/other/says-hi/graders
echo '{"name":"tiny","skills":["./skills/pitch"]}' > .claude-plugin/plugin.json
cat > skills/pitch/SKILL.md <<'MD'
---
name: pitch
description: Pitch one choice to the user. Use when the user asks which option to take.
---
# Pitch

1. Name the options, then argue each one.
2. End on the option you pick.
MD
printf -- '---\nmax_turns: 3\n---\nhi\n' > evals/other/says-hi/prompt.md
printf -- '---\ntype: regex\npattern: hi\nflags: i\n---\n' > evals/other/says-hi/graders/word.md
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
