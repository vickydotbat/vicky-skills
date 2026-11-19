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
printf '<img src="data:image/png;base64,AAA+/tmp/abcAAAA" alt="">\n' > "$fx/p.html"
check "an inlined image whose data spells /tmp/ passes" 'as_rin'
printf '<p>x</p>\n' > "$fx/p.html"; printf '# R\n' > "$fx/R.md"; mkdir -p "$fx/files"
python3 "$root/plugins/vicky-skills/skills/writing/case-file/scripts/bundle.py" "$fx/p.html" "$fx/files" "$fx/new/out" --readme "$fx/R.md" >/dev/null 2>&1
check "a bundle into a folder not made yet makes it" 'ls "$fx"/new/out/*.zip >/dev/null 2>&1'
exit $fail
