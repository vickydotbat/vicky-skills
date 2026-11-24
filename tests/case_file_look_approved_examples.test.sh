#!/usr/bin/env bash
# approved-spec: the examples Vicky asked for on 2026-11-20, after the second
# case file came out plainer than the first hand-made one and left a zip per
# rebuild: a page with contents, a label legend and coloured labels, files
# folded away, a case folder with a fixed layout, and one readable zip per case.
set -u
root=$(cd "$(dirname "$0")/.." && pwd)
kit="$root/plugins/vicky-skills/skills/writing/case-file/scripts"
scratch=$(mktemp -d); trap 'rm -rf "$scratch"' EXIT
fail=0
check() { if (eval "$2"); then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
build() { python3 "$kit/build.py" "$@" 2>&1; }
caught() { python3 "$kit/check.py" "$@" 2>&1; }
bundle() { python3 "$kit/bundle.py" "$@" 2>&1; }
c="$scratch/.case-files/glow"; mkdir -p "$c/sections" "$c/files" "$c/raw" "$c/out"
printf 'void main() {\n  gl_FragColor = vec4(1.0);\n}\n' > "$c/files/glow.frag"
printf '# Glow\n' > "$c/README.md"
cat > "$c/sections/1-answer.html" <<'H'
<!-- KIND research -->
<h1>Glow on the lantern model</h1>
<h2>The answer</h2>
<!-- CLAIM stock | 2026-11-18T20:40+00:00 | run 1 | The lantern glowed at night -->
<!-- CLAIM failed | 2026-11-18T20:10+00:00 | run 0 | A bloom pass washed it out -->
<h2>The shader</h2>
<!-- FILE files/glow.frag -->
H
build "$c" "$c/out/glow.html" >/dev/null
p=$(cat "$c/out/glow.html" 2>/dev/null)

# Given a case file with two sections
# When it is built
# Then the page opens with a contents list linking each section and the timeline
check "CF-E45 the contents list links each section and the timeline" 'python3 - "$c/out/glow.html" <<PY
import re,sys
p=open(sys.argv[1]).read()
nav=re.search(r"<nav[^>]*>(.*?)</nav>",p,re.S)
ids=set(re.findall(r"<h2 id=\"([^\"]+)\"",p))
links=re.findall(r"href=\"#([^\"]+)\"",nav.group(1)) if nav else []
sys.exit(0 if nav and len(links)==3 and set(links)==ids and p.find("<nav")<p.find("<h2") else 1)
PY'

# Given claims labelled stock and failed
# When it is built
# Then the page shows a legend of those two labels only
# And the page still checks clean
check "CF-E46 the legend lists only the labels the page uses" 'grep -q "class=\"legend\"" <<<"$p" && python3 -c "
import re,sys; l=re.search(r\"class=.legend.(.*?)</table>\",sys.argv[1],re.S).group(1); sys.exit(0 if \"stock\" in l and \"failed\" in l and \"estimate\" not in l else 1)" "$p"'
check "CF-E46 a page with its legend checks clean" '[ -n "$p" ] && caught "$c/out/glow.html" >/dev/null'

# Given a built page
# When a reader looks at a claim
# Then its label is a badge in the colour of its kind
check "CF-E47 each label has its own colour" 'for l in stock test-client-only estimate failed not-tested; do grep -q "\[data-evidence=\"\?$l\"\?\] \.label" <<<"$p" || exit 1; done'

# When the page prints to the PDF
check "CF-E54 a code block wraps in print instead of scrolling" 'grep -q "@media print{pre{overflow:visible;white-space:pre-wrap" <<<"$p"'

# Given a file marker
# When it is built
# Then the page folds the file under its name, with its line count and download link
check "CF-E48 a file folds under its name and line count" 'grep -q "<details><summary>glow.frag" <<<"$p" && grep -q "3 lines" <<<"$p" && grep -q "gl_FragColor" <<<"$p"'

# Given a case folder with a stray file at its top
# When it is built
# Then the build stops, naming the stray and the layout
printf x > "$c/notes.txt"
out=$(build "$c" "$c/out/stray.html"); status=$?
check "CF-E49 a stray entry in the case folder stops the build, naming it" '[ "$status" -ne 0 ] && grep -q notes.txt <<<"$out" && grep -q "sections" <<<"$out" && [ ! -e "$c/out/stray.html" ]'
rm "$c/notes.txt"

# Given a built page, its PDF and Markdown
# When it is bundled
# Then the zip is named for the case and its date and minute
# And it unpacks into one folder holding the README, the page in every format and the files
printf '%%PDF-1.4\n' > "$c/out/glow.pdf"; printf '# Glow\n' > "$c/out/glow.md"
bundle "$c/out/glow.html" "$c/files" "$c/out" --readme "$c/README.md" >/dev/null
zips=("$c"/out/*.zip)
check "CF-E50 the zip is named for the case, the date and the minute" '[ "${#zips[@]}" -eq 1 ] && [[ "$(basename "${zips[0]}")" =~ ^glow-[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{4}\.zip$ ]]'
listing=$(python3 -c 'import sys,zipfile; print("\n".join(zipfile.ZipFile(sys.argv[1]).namelist()))' "${zips[0]}" 2>/dev/null)
check "CF-E51 the zip unpacks into one folder with every format" '! grep -qv "^glow/" <<<"$listing" && for f in glow/README.md glow/glow.html glow/glow.pdf glow/glow.md glow/files/glow.frag; do grep -qx "$f" <<<"$listing" || exit 1; done'

# Given a case folder's sections
# When it is bundled
# Then the zip ships them as the document's source
check "CF-E53 the zip ships the sections as the source" 'grep -qx "glow/source/sections/1-answer.html" <<<"$listing"'

# Given a zip whose shipped file holds a scratch path
# When the zip is checked
# Then the check fails, naming the file inside the zip
rm -f "$c/out/glow.pdf"; printf '// built in /tmp/session-1234/glow\n' > "$c/files/leak.frag"
rm -f "$c"/out/*.zip; bundle "$c/out/glow.html" "$c/files" "$c/out" --readme "$c/README.md" >/dev/null
out=$(caught "$c"/out/*.zip); status=$?
check "CF-E52 a leak inside the zip fails, naming the file" '[ "$status" -ne 0 ] && grep -q "leak.frag" <<<"$out"'
rm "$c/files/leak.frag"
exit $fail
