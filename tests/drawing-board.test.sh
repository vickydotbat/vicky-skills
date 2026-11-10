#!/usr/bin/env bash
# board.py and the page's drawing section, past the approved examples: the
# window sits centred, a stretch reads back per side, a size rule names only
# the odd cells of its own kind, Done keeps the latest drawing, and the page
# serves no file from outside the draw.io folder.
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
geo() { python3 -I -c 'import sys,xml.etree.ElementTree as E
for o in E.parse(sys.argv[1]).iter("object"):
    if o.get("label")==sys.argv[2]:
        g=o.find("mxCell/mxGeometry"); print(",".join(g.get(k) for k in ("x","y","width","height")))' "$1" "$2"; }
setgeo() { python3 -I -c 'import sys,xml.etree.ElementTree as E
t=E.parse(sys.argv[1])
for o in t.iter("object"):
    if o.get("label")==sys.argv[2]: o.find("mxCell/mxGeometry").set(sys.argv[3],sys.argv[4])
t.write(sys.argv[5])' "$@"; }

b new --screen 1920x1080 --window "hub=600x400" --box "pack cell=10,10,24,24" -o "$dir/a.drawio"
check "a new sketch is a draw.io file: mxfile, then diagram, then mxGraphModel" 'python3 -I -c "import sys,xml.etree.ElementTree as E;r=E.parse(sys.argv[1]).getroot();sys.exit(not(r.tag==\"mxfile\" and r[0].tag==\"diagram\" and r[0][0].tag==\"mxGraphModel\"))" "$dir/a.drawio"'
check "the window sits centred on the screen" '[ "$(geo "$dir/a.drawio" hub)" = 660,340,600,400 ]'

setgeo "$dir/a.drawio" "pack cell" width 32 "$dir/wide.drawio"
check "a stretch reads back per side" 'b report "$dir/a.drawio" "$dir/wide.drawio" | grep -qx "pack cell width 24 → 32"'
setgeo "$dir/wide.drawio" "pack cell" height 40 "$dir/tall.drawio"
check "a square made oblong reads back per side" 'out=$(b report "$dir/a.drawio" "$dir/tall.drawio"); grep -qx "pack cell width 24 → 32" <<<"$out" && grep -qx "pack cell height 24 → 40" <<<"$out"'

b new --screen 1920x1080 --window "hub=600x400" --rule "same-size=slot" --box "head=10,10,24,24,kind=slot" --box "chest=40,10,24,24,kind=slot" --box "feet=70,10,24,24,kind=slot" --box "logo=100,10,64,64" -o "$dir/r.drawio"
setgeo "$dir/r.drawio" chest width 32 "$dir/r2.drawio"
check "a rule names only the odd cell" 'b report "$dir/r.drawio" "$dir/r2.drawio" | grep -q "odd: chest$"'
check "a box of another kind keeps the rule whole" '! b report "$dir/r.drawio" "$dir/r.drawio" | grep -q "rule broken"'

check "a bad size says what it wants" '! python3 -I "$board" new --screen big --window "hub=600x400" -o "$dir/x.drawio" 2>&1 | grep -q Traceback && python3 -I "$board" new --screen big --window "hub=600x400" -o "$dir/x.drawio" 2>&1 | grep -q "WxH"'
git init -q "$dir/repo"; mkdir -p "$dir/repo/ui"; : > "$dir/repo/ui/hub.nss"
check "a name with a folder in it is refused" '! (cd "$dir/repo" && python3 -I "$board" save "$dir/a.drawio" --name ../escape --code ui/hub.nss) 2>/dev/null && [ ! -e "$dir/escape.drawio" ]'
mkdir -p "$dir/drawio"; printf '<title>draw.io</title>\n' > "$dir/drawio/index.html"; printf 'secret\n' > "$dir/secret.txt"
{ printf '# Sketch\n\n```drawio\n'; cat "$dir/a.drawio"; printf '\n```\n'; } > "$dir/page.md"
DRAWIO_HOME="$dir/drawio" python3 -I "$pagepy" "$dir/page.md" --timeout 60 2> "$dir/page.err" & pids+=($!)
url=""; for _ in $(seq 50); do url=$(grep -om1 'http://127.0.0.1:[0-9]*/' "$dir/page.err"); [ -n "$url" ] && break; sleep 0.1; done
check "no file outside the draw.io folder is served" '[ -n "$url" ] && ! curl -s --path-as-is "${url}drawio/../secret.txt" | grep -q secret && ! curl -s "${url}drawio/..%2fsecret.txt" | grep -q secret'
curl -s -o /dev/null --data-urlencode "xml=<mxGraphModel>latest</mxGraphModel>" "${url}drawing/0"
check "the page holds its scroll while the draw.io frames load" 'curl -s "$url" | grep -q "scrollTo(0,userY)"'
curl -s -o /dev/null --data-urlencode "note=" "${url}done"; sleep 0.3
check "Done keeps the latest drawing" 'grep -q "<mxGraphModel>latest</mxGraphModel>" "$dir/page.md"'
check "a sketch ends in a newline, so a fence written after it stays on its own line" '[ "$(tail -c1 "$dir/a.drawio" | od -An -c | tr -d " ")" = "\\n" ]'
exit $fail
