#!/usr/bin/env bash
# The case-file check's rules past its approved examples: this user's name,
# home folder and host count as this machine, and an inlined image's data
# never does, whatever its base64 happens to spell.
# shellcheck disable=SC2016 # each check's condition is single-quoted on purpose, so check() evals it later
# shellcheck disable=SC2329 # the helpers run inside the eval'd conditions, which shellcheck cannot see
# shellcheck disable=SC2034 # start and status are read inside the eval'd conditions
set -u
root=$(cd "$(dirname "$0")/.." && pwd)
check_py="$root/plugins/vicky-skills/skills/writing/case-file/scripts/check.py"
scratch=$(mktemp -d); trap 'rm -rf "$scratch"' EXIT
# A case file lives in a .case-files folder, the one place under a scratch folder the build accepts.
fx="$scratch/.case-files"; mkdir -p "$fx"
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
# Found by a session whose case folder landed in a worktree: a worktree goes when its effort ends.
kit="$root/plugins/vicky-skills/skills/writing/case-file/scripts"
g() { git -C "$fx/repo" -c user.name=t -c user.email=t@example.invalid "$@"; }
mkdir -p "$fx/repo" && git -C "$fx/repo" init -q -b main && g commit -q --allow-empty -m start && g worktree add -q "$fx/repo/.claude/worktrees/w" 2>/dev/null
for at in "$fx/repo" "$fx/repo/.claude/worktrees/w"; do mkdir -p "$at/.case-files/c/sections"; printf '<!-- KIND research -->\n<h1>C</h1>\n' > "$at/.case-files/c/sections/1.html"; done
out=$(python3 "$kit/build.py" "$fx/repo/.case-files/c" "$fx/repo/.case-files/c/out/c.html" 2>&1); status=$?
check "a case folder at the main checkout's root builds" '[ "$status" -eq 0 ]'
out=$(python3 "$kit/build.py" "$fx/repo/.claude/worktrees/w/.case-files/c" "$fx/wt.html" 2>&1); status=$?
check "a case folder in a linked worktree stops the build and names the main checkout" '[ "$status" -ne 0 ] && grep -q "worktree" <<<"$out" && grep -qF "$fx/repo," <<<"$out" && [ ! -e "$fx/wt.html" ]'
out=$(cd "$fx/repo/.claude/worktrees/w" && python3 "$kit/build.py" .case-files/c "$fx/wt2.html" 2>&1); status=$?
check "a relative case folder in a worktree stops the build too" '[ "$status" -ne 0 ] && [ ! -e "$fx/wt2.html" ]'
mkdir -p "$fx/norepo/.case-files/c/sections"; cp "$fx/repo/.case-files/c/sections/1.html" "$fx/norepo/.case-files/c/sections/"
out=$(GIT_CEILING_DIRECTORIES="$fx" python3 "$kit/build.py" "$fx/norepo/.case-files/c" "$fx/nr.html" 2>&1); status=$?
check "a case folder outside any repo builds" '[ "$status" -eq 0 ]'
out=$(PATH=/nonexistent "$(command -v python3)" "$kit/build.py" "$fx/repo/.case-files/c" "$fx/ng.html" 2>&1); status=$?
check "with no git on PATH the build goes on" '[ "$status" -eq 0 ]'
# Found by a session whose zip held a PNG with "~/" in its pixel bytes.
python3 - "$fx" <<'ZIP'
import struct, sys, zipfile, zlib
def chunk(k, d): return struct.pack(">I", len(d)) + k + d + struct.pack(">I", zlib.crc32(k + d))
head = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 1, 1, 8, 0, 0, 0, 0))
end = chunk(b"IEND", b"")
def png(*chunks): return head + b"".join(chunks) + end
clean = png(chunk(b"tEXt", b"Software\0glow"), chunk(b"zTXt", b"Comment\0\0" + zlib.compress(b"a lantern")),
            chunk(b"iTXt", b"Title\0\0\0en\0\0dusk"), chunk(b"IDAT", b"\0~/x\0")) + chunk(b"tEXt", b"after\0~/x")
leak = lambda c: png(c)
# The scan data after SOS holds what looks like a comment, and must stay pixels.
jclean = b"\xff\xd8\xff\xe0\x00\x04ab\xff\xfe\x00\x06glow\xff\xda\x00\x02\xff\xfe\x00\x05~/x\xff\xd9"
zips = {
    "z": {"c/files/a.png": clean, "c/files/b.jpg": jclean, "c/files/cut.jpg": b"\xff\xd8\xff\xfe\x00\x04ab\xff",
          "c/files/bad.png": png(chunk(b"zTXt", b"Comment\0\0not deflate ~/x"))},
    "t": {"c/files/a.png": clean, "c/notes.txt": b"see ~/x"},
    "m": {"c/files/a.png": leak(chunk(b"zTXt", b"Comment\0\0" + zlib.compress(b"from ~/Pictures")))},
    "e": {"c/files/a.png": leak(chunk(b"tEXt", b"Comment\0from ~/Pictures"))},
    "i": {"c/files/a.png": leak(chunk(b"iTXt", b"Comment\0\0\0en\0\0from ~/Pictures"))},
    "k": {"c/files/a.png": leak(chunk(b"iTXt", b"Comment\0\1\0en\0\0" + zlib.compress(b"from ~/Pictures")))},
    "j": {"c/files/b.jpg": b"\xff\xd8\xff\xe0\x00\x04ab\xff\xfe\x00\x0aab ~/cd\xff\xda\x00\x02\xff\xd9"},
    "f": {"c/files/fake.png": b"see ~/x"},
}
for name, members in zips.items():
    with zipfile.ZipFile(f"{sys.argv[1]}/{name}.zip", "w") as z:
        for k, v in members.items(): z.writestr(k, v)
ZIP
zip_out() { HOME=/srv/rin USER=rin python3 "$check_py" "$fx/$1.zip" 2>&1; }
clean_zip() { out=$(zip_out "$1") && grep -q "check: clean" <<<"$out"; }
refused() { out=$(zip_out "$1"); [ $? -eq 1 ] && grep -qF "$2: " <<<"$out" && ! grep -q Traceback <<<"$out"; }
check "a zip whose images hold ~/ in their pixels, clean text chunks, a cut JPEG and a broken chunk is clean" 'clean_zip z'
check "a text member with ~/ beside such an image is refused" 'refused t c/notes.txt'
check "a PNG zTXt chunk naming a home path is refused" 'refused m c/files/a.png'
check "a PNG tEXt chunk naming a home path is refused" 'refused e c/files/a.png'
check "a PNG iTXt chunk naming a home path is refused" 'refused i c/files/a.png'
check "a compressed PNG iTXt chunk naming a home path is refused" 'refused k c/files/a.png'
check "a JPEG comment naming a home path is refused" 'refused j c/files/b.jpg'
check "a text file named .png is read as text" 'refused f c/files/fake.png'
exit $fail
