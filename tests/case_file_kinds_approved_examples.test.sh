#!/usr/bin/env bash
# approved-spec: the script examples approved on the stars CF-5, CF-6 and CF-7
# of the Case files chart, 2026-11-19. Each runs the case-file skill's build or
# check script on fixtures made here, in a scratch folder of its own.
set -u
root=$(cd "$(dirname "$0")/.." && pwd)
kit="$root/plugins/vicky-skills/skills/writing/case-file/scripts"
scratch=$(TMPDIR=/tmp mktemp -d); vols=(); trap 'rm -rf "$scratch" "${vols[@]}"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
build() { timeout 180 python3 "$kit/build.py" "$@" 2>&1; }
caught() { python3 "$kit/check.py" "$@" 2>&1; }
# The text pdftotext reads from a PDF, one line per line it shows.
pdftext() { pdftotext -layout "$1" - 2>/dev/null; }
# A case folder: .case-files/<name>/sections/ holding the given section files.
case_dir() { mkdir -p "$scratch/repo/.case-files/$1/sections"; echo "$scratch/repo/.case-files/$1"; }
section() { printf '%b' "$3" > "$1/sections/$2"; }
kind='<!-- KIND demonstration -->\n'
tpl='<!-- KIND research -->\n<h1>Glow</h1>\n<p>The glow worked.</p>\n'

# Given a case file template under /tmp
# When the build runs on it
# Then the build stops, names the scratch folder, and writes no page
mkdir -p "$scratch/loose"; printf '%b' "$tpl" > "$scratch/loose/t.html"
out=$(build "$scratch/loose/t.html" "$scratch/loose/page.html"); status=$?
check "CF-E17 a template under /tmp is refused, naming the scratch folder" '[ "$status" -ne 0 ] && grep -q "scratch folder /tmp" <<<"$out" && [ ! -e "$scratch/loose/page.html" ]'

# Given the same template under .case-files
# When the build runs on it
# Then it prints built: and writes the page
d=$(case_dir same); printf '%b' "$tpl" > "$d/t.html"
out=$(build "$d/t.html" "$d/page.html"); status=$?
check "CF-E18 the same template under .case-files builds" '[ "$status" -eq 0 ] && grep -q "^built:" <<<"$out" && [ -s "$d/page.html" ]'

# Given a template under /var/tmp or /dev/shm
# When the build runs on it
# Then the build stops, names that folder, and writes no page
for vol in /var/tmp /dev/shm; do
  [ -d "$vol" ] && [ -w "$vol" ] || { echo "skip CF-E32 under $vol: no writable $vol on this machine"; continue; }
  v=$(mktemp -d "$vol/cf-e32.XXXXXX"); vols+=("$v"); printf '%b' "$tpl" > "$v/t.html"
  out=$(build "$v/t.html" "$v/page.html"); status=$?
  check "CF-E32 a template under $vol is refused, naming it" '[ "$status" -ne 0 ] && grep -q "scratch folder $vol" <<<"$out" && [ ! -e "$v/page.html" ]'
done

# Given a template under .case-files/tmp-fixes
# When the build runs on it
# Then it prints built: and writes the page
d=$(case_dir tmp-fixes); printf '%b' "$tpl" > "$d/t.html"
out=$(build "$d/t.html" "$d/page.html"); status=$?
check "CF-E33 a folder merely named tmp builds" '[ "$status" -eq 0 ] && grep -q "^built:" <<<"$out" && [ -s "$d/page.html" ]'

# Given a template whose kind is not research, demonstration or pitch, or names no kind
# When the build runs
# Then it stops, names the three kinds, and writes no page
d=$(case_dir kinds)
printf '<!-- KIND essay -->\n<p>x</p>\n' > "$d/bad.html"; printf '<p>x</p>\n' > "$d/none.html"
for t in bad none; do
  out=$(build "$d/$t.html" "$d/$t.out.html"); status=$?
  check "CF-E34 a template with kind '$t' stops, naming the three kinds" '[ "$status" -ne 0 ] && grep -q research <<<"$out" && grep -q demonstration <<<"$out" && grep -q pitch <<<"$out" && [ ! -e "$d/$t.out.html" ]'
done

# Given a case folder with three section files
# When the build runs
# Then one page holds all three sections, in file name order
d=$(case_dir three)
section "$d" 2-steps.html '<h2>Second steps</h2>\n<p>Two.</p>\n'
section "$d" 1-answer.html "$kind"'<h2>First answer</h2>\n<p>One.</p>\n'
section "$d" 3-limits.html '<h2>Third limits</h2>\n<p>Three.</p>\n'
build "$d" "$d/out/three.html" >/dev/null
check "CF-E22 three section files make one page, in file name order" 'python3 -c "
import sys; p=open(sys.argv[1]).read(); a,b,c=(p.find(s) for s in (\"First answer\",\"Second steps\",\"Third limits\")); sys.exit(0 if -1<a<b<c else 1)" "$d/out/three.html"'

# Given a case folder with three section files
# When the build runs asking for HTML, PDF and Markdown
# Then all three files appear, and the PDF shows the same sections as the HTML
out=$(build "$d" "$d/out/all.html" --formats html,pdf,md); status=$?
check "CF-E23 one build writes HTML, PDF and Markdown" '[ "$status" -eq 0 ] && [ -s "$d/out/all.html" ] && [ -s "$d/out/all.pdf" ] && [ -s "$d/out/all.md" ]'
check "CF-E23 the PDF shows the same sections as the HTML" '[ -s "$d/out/all.pdf" ] && t=$(pdftext "$d/out/all.pdf") && grep -q "First answer" <<<"$t" && grep -q "Second steps" <<<"$t" && grep -q "Third limits" <<<"$t"'

# Given a section that names the user's home folder
# When the check runs on the built PDF and the built Markdown
# Then it refuses each one, naming the line
# (The build runs as another user, so its own check passes the page; the check then runs as the user the section names.)
d=$(case_dir homeleak)
section "$d" 1-notes.html "$kind"'<h2>Notes</h2>\n<p>Kept in /srv/rin/notes for now.</p>\n'
HOME=/srv/other USER=other build "$d" "$d/out/leak.html" --formats html,pdf,md >/dev/null
for f in leak.pdf leak.md; do
  out=$(HOME=/srv/rin USER=rin caught "$d/out/$f"); status=$?
  check "CF-E24 the check refuses the built $f, naming the line" '[ -s "$d/out/$f" ] && [ "$status" -ne 0 ] && grep -Eq "line [0-9]+:.*srv/rin" <<<"$out"'
done

# Given a request for a format the build doesn't know
# When the build runs
# Then it stops, names the format, and writes nothing
d=$(case_dir formats); section "$d" 1-a.html "$kind"'<h2>A</h2>\n'
out=$(build "$d" "$d/out/x.html" --formats odt); status=$?
check "CF-E25 an unknown format stops the build, naming it, and writes nothing" '[ "$status" -ne 0 ] && grep -q odt <<<"$out" && [ -z "$(ls -A "$d/out" 2>/dev/null)" ]'

# Given a request for html and docx
# When the build runs
# Then it stops, names docx, and writes no HTML either
out=$(build "$d" "$d/out/y.html" --formats html,docx); status=$?
check "CF-E38 one unknown format among known ones writes nothing" '[ "$status" -ne 0 ] && grep -q docx <<<"$out" && [ ! -e "$d/out/y.html" ]'

# Given a case folder whose section names a home folder
# When the build runs asking for HTML, PDF and Markdown
# Then it refuses, names the line, and leaves none of the three files
d=$(case_dir leakbuild)
section "$d" 1-notes.html "$kind"'<h2>Notes</h2>\n<p>Kept in /srv/rin/notes for now.</p>\n'
out=$(HOME=/srv/rin USER=rin build "$d" "$d/out/l.html" --formats html,pdf,md); status=$?
check "CF-E36 a leak refuses the build, naming the line, and leaves no file" '[ "$status" -ne 0 ] && grep -Eq "line [0-9]+:.*srv/rin" <<<"$out" && [ ! -e "$d/out/l.html" ] && [ ! -e "$d/out/l.pdf" ] && [ ! -e "$d/out/l.md" ]'

# Given a case folder with no section files
# When the build runs
# Then it stops, says the folder has none, and writes nothing
d=$(case_dir empty)
out=$(build "$d" "$d/out/e.html"); status=$?
check "CF-E37 an empty case folder stops the build and writes nothing" '[ "$status" -ne 0 ] && grep -qi "no section" <<<"$out" && [ -z "$(ls -A "$d/out" 2>/dev/null)" ]'

# Given a machine with no headless browser
# When the build runs asking for a PDF
# Then it stops naming the missing browser and writes no file
d=$(case_dir nobrowser); section "$d" 1-a.html "$kind"'<h2>A</h2>\n'
mkdir -p "$scratch/bin"; for t in python3 convert; do ln -sf "$(command -v $t)" "$scratch/bin/$t"; done
out=$(PATH="$scratch/bin" CASE_FILE_BROWSER= "$scratch/bin/python3" "$kit/build.py" "$d" "$d/out/n.html" --formats html,pdf 2>&1); status=$?
check "CF-E39 no headless browser stops a PDF build and writes no file" '[ "$status" -ne 0 ] && grep -qi "browser" <<<"$out" && [ -z "$(ls -A "$d/out" 2>/dev/null)" ]'

# Given a claim with no date and time
# When the case file is built
# Then the build stops and names that claim
d=$(case_dir undated)
section "$d" 1-a.html "$kind"'<!-- CLAIM stock |  | ticket check 2 | The lantern glowed at night -->\n'
out=$(build "$d" "$d/out/u.html"); status=$?
check "CF-E40 an undated claim stops the build and names it" '[ "$status" -ne 0 ] && grep -q "The lantern glowed at night" <<<"$out" && [ ! -e "$d/out/u.html" ]'

# Given events out of order, with times in different zones
# When the case file is built
# Then the timeline lists them oldest first, each time with its zone
d=$(case_dir timeline)
section "$d" 1-a.html "$kind"'<!-- EVENT 2026-11-19T10:00+01:00 | Second, in Paris -->\n<!-- EVENT 2026-11-19T12:00-05:00 | Third, in New York -->\n<!-- EVENT 2026-11-19T08:30Z | First, in London -->\n'
build "$d" "$d/out/t.html" >/dev/null
check "CF-E41 the timeline runs oldest first" 'python3 -c "
import re,sys; p=open(sys.argv[1]).read(); t=p[p.find(\"data-timeline\"):]
a,b,c=(t.find(s) for s in (\"First, in London\",\"Second, in Paris\",\"Third, in New York\")); sys.exit(0 if -1<a<b<c else 1)" "$d/out/t.html"'
tl=$(sed -n '/data-timeline/,$p' "$d/out/t.html" 2>/dev/null | grep -v '<!--')
check "CF-E41 each time shows its zone" 'grep -q "+01:00" <<<"$tl" && grep -q -- "-05:00" <<<"$tl" && grep -Eq "08:30 ?(Z|UTC|\+00:00)" <<<"$tl"'

# Given an approved quote with no time
# When the case file is built
# Then the build stops and names that quote
d=$(case_dir undatedquote)
section "$d" 1-a.html "$kind"'<!-- QUOTE  | Vicky | It has to read as lamplight -->\n'
out=$(build "$d" "$d/out/q.html"); status=$?
check "CF-E42 an undated quote stops the build and names it" '[ "$status" -ne 0 ] && grep -q "It has to read as lamplight" <<<"$out" && [ ! -e "$d/out/q.html" ]'

# Given a research or demonstration page with the sentence "we will ship it"
# When the case file is checked
# Then the check names that sentence
for k in research demonstration; do
  d=$(case_dir "future-$k"); section "$d" 1-a.html "<!-- KIND $k -->\n<p>The glow worked. Next, we will ship it.</p>\n"
  # The build runs the check too, so it refuses the page: the check is then run on the HTML the build would have written.
  built=$(build "$d" "$d/out/f.html"); bstatus=$?
  python3 -c "import sys; sys.path.insert(0, sys.argv[1]); import build; open(sys.argv[3], 'w').write(build.page(sys.argv[2]))" "$kit" "$d" "$d/raw.html" 2>/dev/null
  out=$(caught "$d/raw.html"); status=$?
  check "CF-E43 the check names the future tense on a $k page" '[ "$bstatus" -ne 0 ] && grep -q "we will ship it" <<<"$built" && [ -s "$d/raw.html" ] && [ "$status" -ne 0 ] && grep -q "we will ship it" <<<"$out"'
done

# Given a claim whose visible label differs from its machine-readable one
# When the case file is checked
# Then the check fails and names the claim
printf '<body data-case-kind="research"><p>Kind: research</p>\n<p class="claim" data-evidence="test-client-only">The lantern glowed <span class="label">stock</span></p>\n</body>\n' > "$scratch/repo/mismatch.html"
out=$(caught "$scratch/repo/mismatch.html"); status=$?
check "CF-E44 a label that disagrees with its attribute fails, naming the claim" '[ "$status" -ne 0 ] && grep -q "The lantern glowed" <<<"$out"'
exit $fail
