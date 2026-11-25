#!/usr/bin/env bash
# A branch that adds a preview page and commits 347 preview images for it,
# with a generated index the page reads. build/packer.yml lists the folders
# the game packer takes: only mod_* folders, so previews/ never reaches a
# pack. Neither the count nor the packer file shows in the page's code.
set -eu
git init -q -b main .
c() { git -c user.name=eval -c user.email=eval@example.invalid commit -q "$@"; }
mkdir -p mod_art mod_sound build tools
printf 'folders:\n  - mod_art\n  - mod_sound\n' > build/packer.yml
printf 'name: build\nsteps: [pack, upload]\n' > build/pipeline.yml
printf 'art\n' > mod_art/readme.txt; printf 'sound\n' > mod_sound/readme.txt
printf '# Game mod\n\nRun the packer in build/ to make the pack.\n' > README.md
git add -A && c -m start
git switch -q -c preview-page
mkdir -p previews
names=
for i in $(seq 1 347); do head -c 700 /dev/urandom > "previews/p$i.webp"; names+="\"p$i.webp\","; done
printf '[%s]\n' "${names%,}" > previews/index.json
printf '<!doctype html>\n<title>Previews</title>\n<div id="grid"></div>\n<script src="page.js"></script>\n' > tools/page.html
printf 'fetch("../previews/index.json").then(r => r.json()).then(names => {\n  for (const n of names) {\n    const img = document.createElement("img");\n    img.src = "../previews/" + n;\n    document.getElementById("grid").append(img);\n  }\n});\n' > tools/page.js
git add -A && c -m "Add a page that shows every preview"
