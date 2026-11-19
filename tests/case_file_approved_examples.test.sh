#!/usr/bin/env bash
# approved-spec: the examples approved on the stars CF-1, CF-2 and CF-3 of the
# Case files chart, 2026-11-19. Each runs the case-file skill's build, check or
# bundle script on fixtures made here, in a scratch folder of its own.
set -u
root=$(cd "$(dirname "$0")/.." && pwd)
kit="$root/plugins/vicky-skills/skills/writing/case-file/scripts"
scratch=$(mktemp -d); trap 'rm -rf "$scratch"' EXIT
# A case file lives in a .case-files folder, the one place under a scratch folder the build accepts.
fx="$scratch/.case-files"; mkdir -p "$fx"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
build() { python3 "$kit/build.py" "$@" 2>&1; }
caught() { python3 "$kit/check.py" "$@" 2>&1; }
bundle() { python3 "$kit/bundle.py" "$@" 2>&1; }
# The bytes a page's download link saves, by the name it saves under.
saved() { python3 - "$1" "$2" <<'PY'
import base64, re, sys
page = open(sys.argv[1]).read()
for m in re.finditer(r'<a [^>]*href="data:[^;,]*;base64,([^"]*)"[^>]*download="([^"]*)"', page):
    if m.group(2) == sys.argv[2]:
        sys.stdout.buffer.write(base64.b64decode(m.group(1)))
PY
}
mkdir -p "$fx/case/files"
convert -size 3200x1600 xc:steelblue "$fx/case/files/wide.png" 2>/dev/null
[ -s "$fx/case/files/wide.png" ] || { echo "FAIL fixture: convert made no screenshot"; exit 1; }
printf 'void main() {\n  gl_FragColor = vec4(1.0);\n}\n' > "$fx/case/files/glow.frag"
printf '\x89TEX\x00\x01\x02\xff' > "$fx/case/files/stone.tga"

# Given a template with an image marker and its caption
# When the case file is built
# Then the page shows the image with its caption under it
# And the page loads no file beside itself
printf '<!-- KIND demonstration -->\n# Glow\n\n<!-- IMG files/wide.png | The glow at dusk -->\n' > "$fx/case/img.md"
build "$fx/case/img.md" "$fx/img.html" >/dev/null
check "CF-E1 an image is inlined with its caption under it" 'grep -q "<img [^>]*src=\"data:image/" "$fx/img.html" && grep -Eq "</?img|figcaption" "$fx/img.html" && python3 -c "
import re,sys; p=open(sys.argv[1]).read(); i=p.find(\"<img\"); c=p.find(\"The glow at dusk\"); sys.exit(0 if 0<=i<c else 1)" "$fx/img.html"'
check "CF-E1 the page loads no file beside itself" '[ -s "$fx/img.html" ] && ! grep -Eq "(src|href)=\"[^d#][^\"]*\"" "$fx/img.html"'

# Given a 3200 pixel wide screenshot
# When the case file is built
# Then the page holds it at most 720 pixels wide
python3 - "$fx/img.html" "$fx/shrunk" <<'PY'
import base64, re, sys
m = re.search(r'src="data:image/[^;]*;base64,([^"]*)"', open(sys.argv[1]).read())
open(sys.argv[2], "wb").write(base64.b64decode(m.group(1)) if m else b"")
PY
width=$(identify -format '%w' "$fx/shrunk" 2>/dev/null || echo 99999)
check "CF-E2 a 3200 px screenshot goes in at most 720 px wide" '[ "$width" -le 720 ]'

# Given a template with a file marker naming a shader
# When the case file is built
# Then the page shows the whole shader
# And its download link saves the same bytes
printf '<!-- KIND demonstration -->\n# Shader\n\n<!-- FILE files/glow.frag -->\n' > "$fx/case/text.md"
build "$fx/case/text.md" "$fx/text.html" >/dev/null
check "CF-E3 the page shows the whole shader" 'grep -q "gl_FragColor = vec4(1.0);" "$fx/text.html" && grep -q "void main() {" "$fx/text.html"'
check "CF-E3 its download link saves the same bytes" 'cmp -s <(saved "$fx/text.html" glow.frag) "$fx/case/files/glow.frag"'

# Given a file marker naming a texture
# When the case file is built
# Then the page shows the texture's bytes in hex
# And its download link saves the same bytes
printf '<!-- KIND demonstration -->\n# Texture\n\n<!-- BIN files/stone.tga -->\n' > "$fx/case/bin.md"
build "$fx/case/bin.md" "$fx/bin.html" >/dev/null
check "CF-E4 the page shows the texture's bytes in hex" 'grep -Eiq "89 54 45 58 00 01 02 ff" "$fx/bin.html"'
check "CF-E4 its download link saves the same bytes" 'cmp -s <(saved "$fx/bin.html" stone.tga) "$fx/case/files/stone.tga"'

# Given a file marker naming a file that does not exist
# When the case file is built
# Then the build stops and names that marker
# And no page is written
printf '<!-- KIND demonstration -->\n# Gone\n\n<!-- FILE files/missing.frag -->\n' > "$fx/case/gone.md"
out=$(build "$fx/case/gone.md" "$fx/gone.html"); status=$?
check "CF-E5 a missing file stops the build and names the marker" '[ "$status" -ne 0 ] && grep -q "files/missing.frag" <<<"$out"'
check "CF-E5 no page is written" '[ "$status" -ne 0 ] && grep -q "files/missing.frag" <<<"$out" && [ ! -e "$fx/gone.html" ]'

# Given a built page whose text holds a home folder path
# When the case file is checked
# Then the check fails and names the line
printf '<p>Fine.</p>\n<p>Saved in /home/rin/notes.</p>\n' > "$fx/homepath.html" # local-path-ok
out=$(caught "$fx/homepath.html"); status=$?
check "CF-E6 a home folder path in the page fails and names its line" '[ "$status" -ne 0 ] && grep -q "line 2:" <<<"$out"'

# Given a built page whose shader download holds a scratch folder path
# When the case file is checked
# Then the check fails and names that download
leak=$(printf '// built in /tmp/session-1234/glow\nvoid main() {}\n' | base64 -w0)
printf '<p>The shader.</p>\n<a href="data:text/plain;base64,%s" download="glow.frag">glow.frag</a>\n' "$leak" > "$fx/leak.html"
out=$(caught "$fx/leak.html"); status=$?
check "CF-E7 a scratch path inside a download fails and names the download" '[ "$status" -ne 0 ] && grep -q "glow.frag" <<<"$out"'

# Given a built page with no path, username or host in its text or downloads
# When the case file is checked
# Then the check passes
printf '<!-- KIND demonstration -->\n# All three\n\nKept in tmp, as homework.\n\n<!-- IMG files/wide.png | Dusk -->\n<!-- FILE files/glow.frag -->\n<!-- BIN files/stone.tga -->\n' > "$fx/case/all.md"
build "$fx/case/all.md" "$fx/all.html" >/dev/null
[ -s "$fx/all.html" ] && caught "$fx/all.html" >/dev/null; status=$?
check "CF-E8 a clean page passes" '[ "$status" -eq 0 ]'

# Given a built case file and a folder of its files
# When the case file is bundled
# Then one zip holds a README, the case file and the files in their folders
mkdir -p "$fx/out"
printf '# Glow case file\n' > "$fx/README.md"
bundle "$fx/text.html" "$fx/case/files" "$fx/out" --readme "$fx/README.md" >/dev/null
zips=("$fx"/out/*.zip)
listing=$(python3 -c 'import sys,zipfile; print("\n".join(zipfile.ZipFile(sys.argv[1]).namelist()))' "${zips[0]}" 2>/dev/null)
check "CF-E9 one zip holds a README, the case file and the files in folders" '[ "${#zips[@]}" -eq 1 ] && grep -Eq "(^|/)README(\.md)?$" <<<"$listing" && grep -q "text.html$" <<<"$listing" && grep -Eq "/glow\.frag$" <<<"$listing" && grep -Eq "/stone\.tga$" <<<"$listing"'

# Given an earlier bundle in the output folder
# When the case file is bundled again
# Then the new zip is written beside it
# And nothing in the folder is deleted
printf x > "$fx/out/earlier.zip"
before=$(ls "$fx/out")
bundle "$fx/text.html" "$fx/case/files" "$fx/out" --readme "$fx/README.md" >/dev/null
check "CF-E10 a second bundle is written beside the first" '[ "$(ls "$fx"/out/*.zip | wc -l)" -eq 3 ]'
check "CF-E10 nothing in the folder is deleted" '[ "$(ls "$fx"/out/*.zip | wc -l)" -eq 3 ] && for f in $before; do [ -e "$fx/out/$f" ] || exit 1; done'
exit $fail
