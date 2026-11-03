#!/usr/bin/env bash
# approved-spec: the drawing-board examples, approved 2026-10-31 on the ticket
# "drawing-board: designing a UI together". board.py makes and reads the
# sketches; page.py serves a sketch as a drawing section and takes back the
# messages draw.io's embed mode sends (autosave XML, an exported PNG).
set -u
# No test may reach the user's own editor or browser.
export VISUAL=true EDITOR=true BROWSER=true
root="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/skills/productivity"
board="$root/drawing-board/scripts/board.py"
pagepy="$root/interactive-page/scripts/page.py"
dir=$(mktemp -d)
# page.py reads the desktop's environment through systemctl: this one names the fake browser.
mkdir -p "$dir/desktop"
printf '#!/usr/bin/env bash\necho "BROWSER=true"\n' > "$dir/desktop/systemctl"; chmod +x "$dir/desktop/systemctl"
export PATH="$dir/desktop:$PATH"
pids=()
cleanup() { for p in "${pids[@]}"; do kill "$p" 2>/dev/null; done; rm -rf "$dir"; }
trap cleanup EXIT
export BROWSER=true
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
b() { python3 -I "$board" "$@" 2>/dev/null; }
# A PNG header of the given size, enough for a reader of its size.
png() { python3 -I -c 'import struct,sys,zlib
w,h=int(sys.argv[1]),int(sys.argv[2])
c=lambda t,d: struct.pack(">I",len(d))+t+d+struct.pack(">I",zlib.crc32(t+d))
sys.stdout.buffer.write(b"\x89PNG\r\n\x1a\n"+c(b"IHDR",struct.pack(">IIBBBBB",w,h,8,2,0,0,0))+c(b"IEND",b""))' "$1" "$2"; }
# A box's width and height in a sketch, as "WxH".
size() { python3 -I -c 'import sys,xml.etree.ElementTree as E
for o in E.parse(sys.argv[1]).iter("object"):
    if o.get("label")==sys.argv[2]:
        g=o.find("mxCell/mxGeometry"); print(g.get("width")+"x"+g.get("height"))' "$1" "$2" 2>/dev/null; }
# A sketch with one box changed: label, attribute, value.
edit() { python3 -I -c 'import sys,xml.etree.ElementTree as E
t=E.parse(sys.argv[1])
for o in t.iter("object"):
    if o.get("label")==sys.argv[2]:
        g=o.find("mxCell/mxGeometry"); g.set(sys.argv[3],sys.argv[4])
        if sys.argv[3]=="width": g.set("height",sys.argv[4])
t.write(sys.argv[5])' "$@"; }

# Given a window whose code sets it to 600 by 400 on a 1920 by 1080 screen
# When I ask Claude to put it on the drawing board
# Then my browser shows it as a 600 by 400 box inside a 1920 by 1080 frame
b new --screen 1920x1080 --window "hub=600x400" -o "$dir/a.drawio"
check "a window from code at true scale" '[ "$(size "$dir/a.drawio" screen)" = 1920x1080 ] && [ "$(size "$dir/a.drawio" hub)" = 600x400 ]'

# Given a window I only have a screenshot of
# When I ask Claude to put it on the drawing board
# Then my browser shows the screenshot at its own pixel size inside the screen frame
png 700 450 > "$dir/shot.png"
b new --screen 1920x1080 --screenshot "hub=$dir/shot.png" -o "$dir/s.drawio"
check "a screenshot at its own pixel size" '[ "$(size "$dir/s.drawio" hub)" = 700x450 ] && grep -q "data:image/png" "$dir/s.drawio"'

# Given a sketch with a pack cell 24 wide
# When I resize it to 32 and press Done
# Then Claude tells me "pack cell 24 → 32"
b new --screen 1920x1080 --window "hub=600x400" --box "pack cell=10,10,24,24" -o "$dir/c.drawio"
edit "$dir/c.drawio" "pack cell" width 32 "$dir/c2.drawio"
check "a resize reads back as numbers" 'b report "$dir/c.drawio" "$dir/c2.drawio" | grep -qx "pack cell 24 → 32"'

# Given a sketch I've opened
# When I press Done without changing anything
# Then Claude tells me nothing changed, and the sketch stands approved as it is
check "no change is said, and approved" 'out=$(b report "$dir/c.drawio" "$dir/c.drawio"); grep -q "nothing changed" <<<"$out" && grep -q "approved as it is" <<<"$out"'

# Given a box I've marked as block IconGrid with cell size 32
# When I press Done
# Then Claude's report names that box as an IconGrid with 32 cells
b new --screen 1920x1080 --window "hub=600x400" --box "pack=10,10,200,100,block=IconGrid,cell=32" -o "$dir/p.drawio"
check "a marked box is named by its block" 'b report "$dir/p.drawio" "$dir/p.drawio" | grep -q "pack: IconGrid with 32 cells"'

# Given a sketch whose rule says every slot cell in one window is the same size
# When I make one slot cell 32 while the others stay 24
# Then Claude's report says the rule is broken, and names the odd cell
b new --screen 1920x1080 --window "hub=600x400" --rule "same-size=slot" --box "head=10,10,24,24,kind=slot" --box "chest=40,10,24,24,kind=slot" --box "feet=70,10,24,24,kind=slot" -o "$dir/r.drawio"
edit "$dir/r.drawio" chest width 32 "$dir/r2.drawio"
check "a broken size rule names the odd cell" 'out=$(b report "$dir/r.drawio" "$dir/r2.drawio"); grep -q "rule broken" <<<"$out" && grep -q "chest" <<<"$out" && ! grep -q "head\b.*odd\|feet\b.*odd" <<<"$out"'

# Given a repo whose docs/agents file says "Sketches: docs/sketches/"
# When I approve a sketch of the hub window
# Then the sketch is saved in docs/sketches/
git init -q "$dir/repo"; mkdir -p "$dir/repo/docs/agents" "$dir/repo/ui"
printf '# Domain\n\nSketches: docs/sketches/\n' > "$dir/repo/docs/agents/domain.md"
: > "$dir/repo/ui/hub.nss"
saved=$(cd "$dir/repo" && b save "$dir/c.drawio" --name hub --code ui/hub.nss)
check "a Sketches line picks the folder" '[ -f "$dir/repo/docs/sketches/hub.drawio" ] && [ "$saved" = docs/sketches/hub.drawio ]'

# Given a repo with no Sketches line
# When I approve a sketch of the hub window
# Then the sketch is saved in the folder that holds the hub window's code
git init -q "$dir/repo2"; mkdir -p "$dir/repo2/ui"; : > "$dir/repo2/ui/hub.nss"
(cd "$dir/repo2" && b save "$dir/c.drawio" --name hub --code ui/hub.nss >/dev/null)
check "no Sketches line keeps it beside the code" '[ -f "$dir/repo2/ui/hub.drawio" ]'

# The page serves a sketch from a stand-in draw.io folder.
mkdir -p "$dir/drawio"; printf '<!doctype html><title>draw.io</title>\n' > "$dir/drawio/index.html"
{ printf '# Sketch: hub\n\n```drawio\n'; cat "$dir/c.drawio"; printf '\n```\n'; } > "$dir/page.md"
DRAWIO_HOME="$dir/drawio" python3 -I "$pagepy" "$dir/page.md" --timeout 60 2> "$dir/page.err" & pids+=($!)
url=""; for _ in $(seq 50); do url=$(grep -om1 'http://127.0.0.1:[0-9]*/' "$dir/page.err"); [ -n "$url" ] && break; sleep 0.1; done
html=$(curl -s "$url")

# Given my machine has no network connection
# When I open a sketch, change it and press Done
# Then Claude still reports my changes
check "the page and its canvas stay on this machine" '[ -n "$html" ] && grep -q "drawio/index.html" <<<"$html" && ! grep -oE "https?://[^\"'"'"' )]+" <<<"$html" | grep -vq "^http://127.0.0.1" && curl -sf "${url}drawio/index.html" | grep -q draw.io && grep -q "stealth=1" <<<"$html"'

# Given a page with a drawing section
# When I change the drawing
# Then the answer file holds the drawing's latest XML
new=$(sed 's/width="24" height="24"/width="32" height="32"/' "$dir/c.drawio")
curl -s -o /dev/null --data-urlencode "xml=$new" "${url}drawing/0"
check "a change lands in the file at once" 'grep -q "width=\"32\" height=\"32\"" "$dir/page.md"'

# Given a page with a drawing section
# When I press Done
# Then the answer file also holds a PNG of the drawing
pngdata="data:image/png;base64,$(png 4 4 | base64 -w0)"
curl -s -o /dev/null --data-urlencode "drawing_png.0=$pngdata" "${url}done"
sleep 0.3
check "Done leaves a PNG beside the file, named in it" 'f=$(grep -oE "page\.drawing-0\.png" "$dir/page.md" | head -1); [ -n "$f" ] && head -c 8 "$dir/$f" | grep -q PNG'
exit $fail
