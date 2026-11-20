#!/usr/bin/env bash
# The case-file build's markers and formats past their approved examples: the
# kind line, steps, claims, events and quotes, a pitch's ask, the Markdown, the
# browser it prints with, and the check's PDF reading and label rules.
set -u
root=$(cd "$(dirname "$0")/.." && pwd)
kit="$root/plugins/vicky-skills/skills/writing/case-file/scripts"
scratch=$(mktemp -d); trap 'rm -rf "$scratch"' EXIT
fx="$scratch/.case-files"; mkdir -p "$fx/files"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
build() { timeout 180 python3 "$kit/build.py" "$@" 2>&1; }
caught() { python3 "$kit/check.py" "$@" 2>&1; }
tpl() { printf '%b' "$2" > "$fx/$1.html"; }
printf 'void main() {\n  glow();\n}\n' > "$fx/files/glow.frag"
convert -size 40x20 xc:orange "$fx/files/dusk.png"

tpl full '<!-- KIND research -->\n<h2>Answer</h2>\n<p>The glow worked.</p>\n<ul><li>One point</li></ul>\n<p><a href="https://example.invalid/doc">the doc</a> said so.</p>\n<!-- IMG files/dusk.png | Dusk -->\n<!-- FILE files/glow.frag -->\n<p>Spaced   out.</p>\n<!-- STEP glslangValidator files/glow.frag | printed nothing | exited 0 -->\n<!-- CLAIM test-client-only | 2026-11-18T20:40+00:00 | ticket check 2 | The lantern glowed at night -->\n<!-- EVENT 2026-11-18T20:05+00:00 | The shader compiled -->\n<!-- QUOTE 2026-11-18T21:34+00:00 | Vicky | Lamplight, not neon -->\n<p>After the quote.</p>\n'
out=$(build "$fx/full.html" "$fx/out/full.html" --formats html,md); status=$?
p=$(cat "$fx/out/full.html" 2>/dev/null); md=$(cat "$fx/out/full.md" 2>/dev/null)
check "the build succeeds on every marker" '[ "$status" -eq 0 ]'
check "the page names its kind in its root and its text" 'grep -q "<body data-case-kind=\"research\">" <<<"$p" && grep -q "Kind: research" <<<"$p" && ! grep -q "<!-- *KIND" <<<"$p"'
check "a step shows its command and its expected result" 'grep -q "<code>glslangValidator files/glow.frag</code>" <<<"$p" && grep -q "Expected: printed nothing | exited 0" <<<"$p"'
check "a claim shows its label in words and in its attribute" 'grep -q "data-evidence=\"test-client-only\"" <<<"$p" && grep -q "<span class=\"label\">test client only</span>" <<<"$p" && grep -q "Source: ticket check 2" <<<"$p"'
check "an event shows in the page and the timeline" '[ "$(grep -o "The shader compiled" <<<"$p" | wc -l)" -eq 2 ]'
check "a quote shows its speaker and time, and joins the timeline" 'grep -q "<footer>Vicky, <time" <<<"$p" && grep -q "Vicky: Lamplight, not neon" <<<"$p"'
check "the timeline holds each claim, event and quote, oldest first" 'python3 -c "
import sys; t=sys.argv[1][sys.argv[1].find(\"data-timeline\"):]; a,b,c=(t.find(s) for s in (\"The shader compiled\",\"The lantern glowed\",\"Vicky: Lamplight\")); sys.exit(0 if -1<a<b<c else 1)" "$p"'
check "a UTC time shows its zone as +00:00" 'grep -q "2026-11-18 20:05 +00:00" <<<"$p"'
check "the Markdown keeps headings, lists, links and image captions" 'grep -q "^## Answer" <<<"$md" && grep -q "^- One point" <<<"$md" && grep -q "^\[the doc\](https://example.invalid/doc) said so\.$" <<<"$md" && grep -q "\[image: Dusk\]" <<<"$md" && grep -qx "The glow worked\." <<<"$md" && grep -qx "Spaced out\." <<<"$md"'
check "the Markdown fences each code block and keeps its lines" 'python3 -c "
import sys; m=sys.argv[1]; sys.exit(0 if \"\\n\`\`\`\\nvoid main() {\\n  glow();\\n}\\n\\n\`\`\`\\n\" in m and m.count(\"\`\`\`\") == 4 else 1)" "$md"'
check "the Markdown quotes a quote after a blank line, and nothing after it" 'python3 -c "
import sys; m=sys.argv[1]; sys.exit(0 if \"\\n\\n> Lamplight, not neon\" in m and \"\\n\\nAfter the quote.\" in m else 1)" "$md"'
check "the Markdown holds no inlined data" '[ -n "$md" ] && ! grep -q "data:" <<<"$md" && ! grep -q "Download glow.frag\](" <<<"$md"'
check "a research page has no ask note" '! grep -q "asks you to act" <<<"$p"'

tpl step '<!-- KIND demonstration -->\n<!-- STEP make glow -->\n'
out=$(build "$fx/step.html" "$fx/out/step.html"); status=$?
check "a step with no expected result stops the build, naming it" '[ "$status" -ne 0 ] && grep -q "make glow" <<<"$out"'
tpl label '<!-- KIND demonstration -->\n<!-- CLAIM proven | 2026-11-18T20:40+00:00 | run 1 | It glowed -->\n'
out=$(build "$fx/label.html" "$fx/out/label.html"); status=$?
check "a claim with an unknown label stops the build, naming it" '[ "$status" -ne 0 ] && grep -q "It glowed" <<<"$out" && grep -q proven <<<"$out"'
tpl parts '<!-- KIND demonstration -->\n<!-- QUOTE 2026-11-18T20:40+00:00 | Lamplight -->\n'
out=$(build "$fx/parts.html" "$fx/out/parts.html"); status=$?
check "a marker with too few parts stops the build, naming it" '[ "$status" -ne 0 ] && grep -q "Lamplight" <<<"$out"'

tpl pitch '<!-- KIND pitch -->\n<p>The glow worked for us.</p>\n<!-- ASK -->\n<p>We will help you adopt it.</p>\n<!-- END ASK -->\n'
out=$(build "$fx/pitch.html" "$fx/out/pitch.html"); status=$?
check "a pitch may use the future tense inside its ask" '[ "$status" -eq 0 ] && grep -q "<section class=\"ask\" data-ask>" "$fx/out/pitch.html"'
check "a pitch says at the top that it asks the reader to act" 'grep -q "asks you to act" "$fx/out/pitch.html"'
tpl pitch2 '<!-- KIND pitch -->\n<p>We will help you adopt it.</p>\n'
out=$(build "$fx/pitch2.html" "$fx/out/pitch2.html"); status=$?
check "a pitch's future tense outside its ask stops the build" '[ "$status" -ne 0 ] && grep -q "We will help you" <<<"$out"'
check "a tense hit is not called a leak of this machine" '! grep -q "names this machine" <<<"$out"'
printf '<body data-case-kind="research"><section class="ask" data-ask><p>We will ship it.</p></section></body>\n' > "$scratch/ask.html"
out=$(caught "$scratch/ask.html"); status=$?
check "only a pitch's ask may use the future tense" '[ "$status" -ne 0 ] && grep -q "We will ship it" <<<"$out"'

printf '<body data-case-kind="research"><p class="claim" data-evidence="proven">It glowed <span class="label">proven</span></p></body>\n' > "$scratch/unknown.html"
out=$(caught "$scratch/unknown.html"); status=$?
check "a claim whose label is no known label fails the check, naming it" '[ "$status" -ne 0 ] && grep -q "claim It glowed" <<<"$out" && ! grep -q Traceback <<<"$out"'
printf '<body data-case-kind="research"><p class="claim" data-evidence="stock">It glowed</p></body>\n' > "$scratch/nolabel.html"
check "a claim with no visible label fails the check" '! caught "$scratch/nolabel.html" >/dev/null'

printf '#!/bin/sh\nexit 0\n' > "$scratch/quiet-browser"; printf '#!/bin/sh\nexit 3\n' > "$scratch/broken-browser"; chmod +x "$scratch"/*-browser
tpl pdf '<!-- KIND research -->\n<p>x</p>\n'
out=$(CASE_FILE_BROWSER="$scratch/quiet-browser" build "$fx/pdf.html" "$fx/out/q.html" --formats pdf); status=$?
check "the browser CASE_FILE_BROWSER names is the one used, and one that prints nothing stops the build" '[ "$status" -ne 0 ] && grep -q "quiet-browser printed no PDF" <<<"$out" && [ ! -e "$fx/out/q.pdf" ]'
out=$(CASE_FILE_BROWSER="$scratch/broken-browser" build "$fx/pdf.html" "$fx/out/b.html" --formats pdf); status=$?
check "a browser that fails stops the build, naming it" '[ "$status" -ne 0 ] && grep -q "broken-browser could not print" <<<"$out"'

printf 'not a pdf\n' > "$scratch/bad.pdf"
out=$(caught "$scratch/bad.pdf"); status=$?
check "a PDF pdftotext can't read is refused" '[ "$status" -ne 0 ] && grep -q "could not read" <<<"$out"'
mkdir -p "$scratch/bin"; ln -sf "$(command -v python3)" "$scratch/bin/python3"
out=$(PATH="$scratch/bin" "$scratch/bin/python3" "$kit/check.py" "$scratch/bad.pdf" 2>&1); status=$?
check "a PDF with no pdftotext to read it is refused" '[ "$status" -ne 0 ] && grep -q "pdftotext is missing" <<<"$out"'
# The contents list, the legend and the zip check, past their approved examples.
tpl twins '<!-- KIND research -->\n<h2>Answer</h2>\n<h2>Answer</h2>\n<h2 id="keep">Kept</h2>\n<!-- CLAIM stock | 2026-11-18T20:40+00:00 | run 1 | It glowed -->\n'
build "$fx/twins.html" "$fx/out/twins.html" --formats html,md >/dev/null; p=$(cat "$fx/out/twins.html" 2>/dev/null); md=$(cat "$fx/out/twins.md" 2>/dev/null)
check "two sections of one name get two ids, and a given id stays" 'grep -q "<h2 id=\"answer\">" <<<"$p" && grep -q "<h2 id=\"answer-2\">" <<<"$p" && grep -q "<h2 id=\"keep\">Kept" <<<"$p" && grep -q "href=\"#keep\"" <<<"$p" && ! grep -q "id=\"keep\" id=" <<<"$p"'
check "the Markdown legend is a table with its header rule" 'grep -A2 -x "| Label | Means |" <<<"$md" | sed -n 2p | grep -qx "| --- | --- |" && grep -q "^| stock | " <<<"$md"'
tpl lone '<!-- KIND research -->\n<h2>Only</h2>\n<p>One section.</p>\n'
build "$fx/lone.html" "$fx/out/lone.html" >/dev/null
check "a page of one section has no contents list" '[ -s "$fx/out/lone.html" ] && ! grep -q "<nav" "$fx/out/lone.html"'
tpl flat '<!-- KIND research -->\n<p>No sections.</p>\n<!-- CLAIM failed | 2026-11-18T20:40+00:00 | run 1 | It dimmed -->\n<!-- TIMELINE -->\n'
build "$fx/flat.html" "$fx/out/flat.html" --formats html,md >/dev/null
check "a page with no section still shows its legend" 'grep -q "class=\"legend\"" "$fx/out/flat.html" && grep -q "No sections" "$fx/out/flat.html"'
tpl fold '<!-- KIND research -->\n<!-- FILE files/glow.frag -->\n'
build "$fx/fold.html" "$fx/out/fold.html" --formats html,md >/dev/null
check "a folded file starts its own Markdown paragraph" 'grep -qx "glow.frag (3 lines).*" "$fx/out/fold.md"'
printf 'x\n' > "$fx/files/one.txt"; tpl one '<!-- KIND research -->\n<!-- FILE files/one.txt -->\n'
build "$fx/one.html" "$fx/out/one.html" >/dev/null
check "a one-line file says 1 line" 'grep -q "(1 line)" "$fx/out/one.html"'
mkdir -p "$scratch/bz/sections"; printf '# R\n' > "$scratch/bz/R.md"; printf '<p>x</p>\n' > "$scratch/bz/sections/1.html"; printf '<p>x</p>\n' > "$scratch/bz/p.html"
python3 "$kit/bundle.py" "$scratch/bz/p.html" "$fx/files" "$scratch/bz/out" --readme "$scratch/bz/R.md" >/dev/null
python3 "$kit/bundle.py" "$scratch/bz/p.html" "$fx/files" "$scratch/bz/out" --readme "$scratch/bz/R.md" >/dev/null
z=$(ls "$scratch/bz/out"); 
check "two bundles in one minute leave one zip, the second" '[ "$(wc -l <<<"$z")" -eq 1 ] && [[ "$z" =~ ^p-[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{4}-2\.zip$ ]] || [[ "$z" =~ ^p-[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{4}\.zip$ ]] && [ "$(wc -l <<<"$z")" -eq 1 ]'
check "a bundle ships no source when the page has no case folder beside it" '! python3 -c "import sys,zipfile; sys.exit(0 if any(\"source/\" in n for n in zipfile.ZipFile(sys.argv[1]).namelist()) else 1)" "$scratch/bz/out/$z"'
python3 - "$scratch/dir.zip" "$scratch/bad.pdf" <<'PY'
import sys, zipfile
with zipfile.ZipFile(sys.argv[1], "w") as z:
    z.writestr("case/", "")
    z.writestr("case/README.md", "# Fine\n")
PY
check "a zip with a folder entry and clean files checks clean" 'caught "$scratch/dir.zip" >/dev/null'
python3 -c 'import sys,zipfile; zipfile.ZipFile(sys.argv[1],"w").write(sys.argv[2],"case/case.pdf")' "$scratch/badpdf.zip" "$scratch/bad.pdf"
out=$(caught "$scratch/badpdf.zip"); status=$?
check "a zip whose PDF pdftotext can't read is refused" '[ "$status" -ne 0 ] && grep -q "could not read" <<<"$out"'
exit $fail
