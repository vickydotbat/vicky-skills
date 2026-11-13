#!/usr/bin/env bash
# board.py's edge cases, beside the drawing board's approved examples: each
# refusal and its words, the draw.io frame cells, and what report and save do
# with boxes, properties, rules and folders the main tests don't reach.
set -u
board="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/skills/productivity/drawing-board/scripts/board.py"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
err() { python3 -I "$board" "$@" 2>&1 >/dev/null; }
usage_new='  board.py new --screen WxH (--window NAME=WxH | --screenshot NAME=FILE.png)'
usage_save='  board.py save SKETCH --name NAME --code PATH'

printf 'not a png at all, honestly' > "$dir/fake.png"
check "a screenshot that is no PNG is refused" '[ "$(err new --screen 800x600 --screenshot w="$dir/fake.png" -o "$dir/x.drawio")" = "board: $dir/fake.png is not a PNG" ]'
check "a flag with no value is refused" '[ "$(err new --screen)" = "board: --screen needs a value" ]'
check "an unknown flag is refused" '[ "$(err new --bogus 1)" = "board: unknown flag --bogus" ]'
check "new with no screen gives its usage" '[ "$(err new --window w=10x10 -o "$dir/x.drawio")" = "$usage_new" ]'
check "new with no output gives its usage" '[ "$(err new --screen 800x600 --window w=10x10)" = "$usage_new" ]'
check "new with no window or screenshot gives its usage" '[ "$(err new --screen 800x600 -o "$dir/x.drawio")" = "$usage_new" ]'

python3 -I "$board" new --screen 800x600 --window w=400x300 --box a=1,2,30,40,kind=slot,block=Grid --box b=5,5,10,10 --rule same-size=slot --rule other=x -o "$dir/before.drawio"
check "a sketch opens with draw.io's two root cells" 'grep -qF "<root><mxCell id=\"0\" /><mxCell id=\"1\" parent=\"0\" />" "$dir/before.drawio"'
python3 -I "$board" new --screen 800x600 --window w=400x300 --box a=1,2,30,40,kind=slot,block=Other --box c=7,7,10,10,kind=slot --rule same-size=slot --rule other=slot -o "$dir/after.drawio"
out=$(python3 -I "$board" report "$dir/before.drawio" "$dir/after.drawio")
check "a new box is named with its size" 'grep -qx "c: new, 10x10" <<<"$out"'
check "a removed box is named" 'grep -qx "b: removed" <<<"$out"'
check "a changed property shows its old and new value" 'grep -qx "a block Grid → Other" <<<"$out"'
check "an unchanged property and the rules line are not named" '! grep -q "a kind" <<<"$out" && ! grep -q "rules" <<<"$out"'
check "a rule other than same-size is not checked" '[ "$(grep -c "^rule broken" <<<"$out")" = 1 ]'
check "same-size names the odd box" 'grep -q "^rule broken: every slot cell is the same size" <<<"$out"'
sed 's|<object label="b"[^>]*>|<object label="b" id="box1"><note/>|; s|<mxCell style="rounded=0;whiteSpace=wrap;" vertex="1" parent="window"><mxGeometry x="5" y="5" width="10" height="10" as="geometry" /></mxCell>||' "$dir/before.drawio" > "$dir/nogeo.drawio"
grep -q '<note/>' "$dir/nogeo.drawio" || echo "FAIL fixture: no geometry-free box"
check "a box with no geometry is left out" '! python3 -I "$board" report "$dir/nogeo.drawio" "$dir/before.drawio" | grep -q "^b: new"; python3 -I "$board" report "$dir/nogeo.drawio" "$dir/before.drawio" | grep -qx "b: new, 10x10"'

git init -q "$dir/r"; mkdir -p "$dir/r/docs/agents" "$dir/r/src"
printf 'Sketches: notes\n' > "$dir/r/docs/agents/x.txt"; printf 'nothing here\n' > "$dir/r/docs/agents/a.md"
saved=$(cd "$dir/r" && python3 -I "$board" save "$dir/before.drawio" --name panel --code src/panel.py)
check "with no Sketches line in a .md file, the sketch sits beside the code" '[ "$saved" = "src/panel.drawio" ] && [ -f "$dir/r/src/panel.drawio" ]'
check "a name with a folder in it is refused" '[ "$(cd "$dir/r" && err save "$dir/before.drawio" --name a/b --code src/p.py)" = "board: the name a/b must be a plain name, with no folder in it" ]'
check "save with no code gives its usage" '[ "$(cd "$dir/r" && err save "$dir/before.drawio" --name panel)" = "$usage_save" ]'
mkdir "$dir/plain"
saved=$(cd "$dir/plain" && python3 -I "$board" save "$dir/before.drawio" --name panel --code panel.py)
check "outside a git checkout, the sketch goes in the current folder" '[ "$saved" = "panel.drawio" ] && [ -f "$dir/plain/panel.drawio" ]'

doc=$(python3 -I -c 'import ast,sys; print(ast.get_docstring(ast.parse(open(sys.argv[1]).read())))' "$board")
check "no command prints the whole usage" '[ "$(err)" = "$doc" ]'
check "report with one file prints the usage" '[ "$(err report "$dir/before.drawio")" = "$doc" ]'
check "save with nothing after it prints the usage" '[ "$(err save)" = "$doc" ]'
check "an unknown command prints the usage" '[ "$(err draw)" = "$doc" ]'
exit $fail
