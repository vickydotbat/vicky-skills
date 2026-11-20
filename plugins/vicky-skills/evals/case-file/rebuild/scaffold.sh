#!/usr/bin/env bash
# A case file built and bundled in an earlier session, with its zip in out/
# and a run log someone dropped at the top of the case folder.
set -eu
git init -q -b main .
printf '.case-files/\n' > .gitignore
mkdir -p .case-files/glow/sections .case-files/glow/files/img .case-files/glow/out
convert -size 1200x600 xc:darkorange .case-files/glow/files/img/dusk.png
printf 'run 1: glow on at 20:40\n' > .case-files/glow/run1.log
cat > .case-files/glow/sections/1-answer.html <<'H'
<!-- KIND research -->
<h1>Glow on the lantern model</h1>
<h2>The answer</h2>
<p>The lantern glowed warm at night, from a fragment shader.</p>
<!-- CLAIM stock | 2026-11-18T20:40+00:00 | run 1 | The lantern glowed at night -->
<!-- IMG files/img/dusk.png | The lantern at dusk -->
<h2>Not proven</h2>
<!-- CLAIM not-tested | 2026-11-18T21:00+00:00 | no run | The glow on other lanterns -->
H
printf 'Glow case file\n' > .case-files/glow/README.md
printf 'PK-earlier' > .case-files/glow/out/glow-20261119-120000-1.zip
git add .gitignore && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
