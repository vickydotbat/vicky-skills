#!/usr/bin/env bash
# A case file begun in an earlier session: one section, one screenshot and one
# approved quote, with a new screenshot waiting beside the repo's root.
set -eu
git init -q -b main .
printf '.case-files/\n.tools/\n' > .gitignore
# The agent's shell has no ImageMagick or browser on PATH, so link the scaffold's own.
mkdir -p .tools && for t in convert chromium; do ln -s "$(readlink -f "$(command -v $t)")" .tools/$t; done
mkdir -p .case-files/glow/sections .case-files/glow/files/img .case-files/glow/out
# Each picture shows a lit lantern, so the skill's cut of an empty image keeps it.
lantern() { convert -size 1200x600 "xc:$1" -fill '#ffd27a' -draw 'circle 600,300 600,200' -fill white -pointsize 48 -annotate +420+540 "lantern at $2" "$3"; }
lantern darkorange dusk .case-files/glow/files/img/dusk.png
lantern midnightblue night night.png
cat > .case-files/glow/sections/1-glow.html <<'H'
<!-- KIND demonstration -->
<h1>Glow on the lantern model</h1>
<h2>What we built</h2>
<p>The lantern got a warm glow from a fragment shader.</p>
<!-- IMG files/img/dusk.png | The lantern at dusk -->
H
cat > .case-files/glow/quotes.md <<'Q'
# Quotes for the glow case file

## Quote 1
Said 2026-11-18T21:34+00:00, by the user.

> The glow has to read as lamplight, not neon.

- [x] approve
Q
git add .gitignore night.png && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
