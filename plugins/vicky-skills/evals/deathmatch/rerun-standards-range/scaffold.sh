#!/usr/bin/env bash
# A follow-up deathmatch whose new commit changes only Markdown.
set -eu
git init -q -b main .
printf '# calc\n' > README.md
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
printf '## Proof\n\nDeathmatch verdict for a1b2c3d: 0 proven findings\n' > body.md
