#!/usr/bin/env bash
# The case-file check's rules past its approved examples: this user's name,
# home folder and host count as this machine, and an inlined image's data
# never does, whatever its base64 happens to spell.
set -u
root=$(cd "$(dirname "$0")/.." && pwd)
check_py="$root/plugins/vicky-skills/skills/writing/case-file/scripts/check.py"
fx=$(mktemp -d); trap 'rm -rf "$fx"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
page() { printf '<p>%s</p>\n' "$1" > "$fx/p.html"; }
as_rin() { HOME=/srv/rin USER=rin python3 "$check_py" "$fx/p.html" >/dev/null 2>&1; }

page "Kept in /srv/rin/notes."
check "the home folder outside /home counts" '! as_rin'
page "Kept in /data/rin/notes."
check "this user's name as a folder in a rooted path counts" '! as_rin'
page "Mail rin@example.invalid for it."
check "this user's name before an @ counts" '! as_rin'
page "Ask Rin, or read the rinse notes."
check "the user's name as a plain word passes" 'as_rin'
page "Kept in /srv/box/notes."
check "a home folder not named for the user counts" '! HOME=/srv/box USER=rin python3 "$check_py" "$fx/p.html" >/dev/null 2>&1'
page "Built on $(hostname | cut -d. -f1)."
check "this host's name counts" '! as_rin'
printf '<a href="data:text/plain,a%%20glow" download="p.txt">a</a>\n' > "$fx/p.html"
check "a clean percent-encoded download passes" 'as_rin'
printf '<img src="data:image/png;base64,AAA+/tmp/abcAAAA" alt="">\n' > "$fx/p.html"
check "an inlined image whose data spells /tmp/ passes" 'as_rin'
printf '<p>x</p>\n' > "$fx/p.html"; printf '# R\n' > "$fx/R.md"; mkdir -p "$fx/files"
python3 "$root/plugins/vicky-skills/skills/writing/case-file/scripts/bundle.py" "$fx/p.html" "$fx/files" "$fx/new/out" --readme "$fx/R.md" >/dev/null 2>&1
check "a bundle into a folder not made yet makes it" 'ls "$fx"/new/out/*.zip >/dev/null 2>&1'
# Found by the deathmatch on pull request 264: leaks the first check missed.
x=$(printf '/srv/box/x\n' | base64 -w0)
for form in "<a href='data:text/plain;base64,$x' download='a.txt'>a</a>" "<a download=\"a.txt\" href=\"data:text/plain;base64,$x\">a</a>" "<a href=data:text/plain;base64,$x download=a.txt>a</a>"; do
  printf '%s\n' "$form" > "$fx/p.html"
  check "a download written as $form is decoded and scanned" '! HOME=/srv/box USER=rin python3 "$check_py" "$fx/p.html" >/dev/null 2>&1'
done
printf '<a href="data:text/plain;base64,!!!abc" download="a">a</a>\n' > "$fx/p.html"
out=$(as_rin_out() { HOME=/srv/rin USER=rin python3 "$check_py" "$fx/p.html" 2>&1; }; as_rin_out); status=$?
check "a download that will not decode is refused by name, not passed" '[ "$status" -ne 0 ] && grep -q "download a" <<<"$out" && ! grep -q Traceback <<<"$out"'
page "&#47;srv&#47;rin&#47;notes"
check "a path written as HTML entities counts" '! as_rin'
page "Kept in ~/Projects/glow."
check "a path from the home folder written with a tilde counts" '! as_rin'
page "Copied from ../sibling/glow."
check "a path that climbs out of the folder counts" '! as_rin'
printf '<a href="data:text/plain,%%2Fsrv%%2Fbox%%2Fx" download="p.txt">a</a>\n' > "$fx/p.html"
check "a percent-encoded download is decoded and scanned" '! HOME=/srv/box USER=rin python3 "$check_py" "$fx/p.html" >/dev/null 2>&1'
printf '<img src="data:image/png;base64,%s" alt="">\n' "$(printf 'PNG /tmp/x' | base64 -w0)" > "$fx/p.html"
check "an inlined image's bytes are never scanned as text" 'as_rin'
mkdir -p "$fx/t"; echo outside > "$fx/outside.txt"; printf '<!-- FILE ../outside.txt -->\n' > "$fx/t/t.html"
out=$(python3 "$root/plugins/vicky-skills/skills/writing/case-file/scripts/build.py" "$fx/t/t.html" "$fx/t/o.html" 2>&1); status=$?
check "a marker naming a file outside the template's folder stops the build" '[ "$status" -ne 0 ] && grep -q "outside.txt" <<<"$out" && [ ! -e "$fx/t/o.html" ]'
exit $fail
