#!/usr/bin/env bash
# A game mod repo with an agent file of rules about how the game client behaves.
set -eu
git init -q -b main .
mkdir -p textures
printf -- '- Texture names are 16 characters at most.\n' > AGENTS.md
printf 'TGA placeholder\n' > textures/glass01.tga
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
