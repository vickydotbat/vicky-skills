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
# Runaway findings: an image bomb and a huge file stop the build instead of eating the machine.
python3 - "$fx/t/bomb.png" <<'BOMB'
import struct, sys, zlib
w = h = 60000
def chunk(k, d): return struct.pack(">I", len(d)) + k + d + struct.pack(">I", zlib.crc32(k + d))
z = zlib.compressobj(9); row = b"\0" * (1 + w // 8); data = b"".join(z.compress(row) for _ in range(h)) + z.flush()
open(sys.argv[1], "wb").write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 1, 0, 0, 0, 0)) + chunk(b"IDAT", data) + chunk(b"IEND", b""))
BOMB
printf '<!-- IMG bomb.png | x -->\n' > "$fx/t/b.html"
start=$SECONDS; out=$(timeout 60 python3 "$root/plugins/vicky-skills/skills/writing/case-file/scripts/build.py" "$fx/t/b.html" "$fx/t/b.out" 2>&1); status=$?
check "an image bomb stops the build within 30 seconds" '[ "$status" -ne 0 ] && [ "$status" -ne 124 ] && [ $((SECONDS - start)) -lt 30 ] && grep -q "bomb.png" <<<"$out"'
truncate -s 30M "$fx/t/big.bin"; printf '<!-- BIN big.bin -->\n' > "$fx/t/g.html"
out=$(python3 "$root/plugins/vicky-skills/skills/writing/case-file/scripts/build.py" "$fx/t/g.html" "$fx/t/g.out" 2>&1); status=$?
check "a file over the size cap stops the build and names it" '[ "$status" -ne 0 ] && grep -q "big.bin" <<<"$out" && grep -qi "too big" <<<"$out"'
exit $fail
