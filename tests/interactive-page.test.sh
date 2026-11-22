#!/usr/bin/env bash
# shellcheck disable=SC2016 # check() evals its single-quoted condition later
# shellcheck disable=SC2034 # names set here are read inside check()'s eval
# page.py's decisions beyond the approved examples: comments, odd answers,
# a second Done, the timeout and bad arguments. Runs the page with a
# stand-in browser that records its address.
set -u
# No test may reach the user's own editor or browser.
export VISUAL=true EDITOR=true BROWSER=true
page="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/skills/writing/interactive-page/scripts/page.py"
scratch=$(mktemp -d)
# page.py hands the browser the desktop session's environment, read through
# systemctl. This desktop names the fake browser, so a mutant that drops
# BROWSER still reaches no real one.
mkdir -p "$scratch/desktop"
printf '#!/usr/bin/env bash\necho "PATH=$PATH"\necho "BROWSER=${BROWSER:-true}"\n' >"$scratch/desktop/systemctl"
chmod +x "$scratch/desktop/systemctl"
export PATH="$scratch/desktop:$PATH"
pid=""
trap '[ -n "$pid" ] && kill "$pid" 2>/dev/null; rm -rf "$scratch"' EXIT
printf '#!/usr/bin/env bash\necho "$1" >"%s/url"\n' "$scratch" >"$scratch/browser"
chmod +x "$scratch/browser"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

cat >"$scratch/template.md" <<'EOF'
# Drafts

## One
a.txt:1
- [x] approve

```text
First line
second line
```

## Two
b.txt:1

```text
Other
```

1. [~] Try it → it works
   notes: was slow
EOF

start() { # file [timeout]
  rm -f "$scratch/url"
  PATH="${PYPATH:-$PATH}" BROWSER="$scratch/browser" python3 -I "$page" "$1" --timeout "${2:-30}" 2>/dev/null &
  pid=$!
  for _ in $(seq 50); do [ -s "$scratch/url" ] && break; sleep 0.1; done
  url=$(cat "$scratch/url" 2>/dev/null)
}
post() { # path pairs...
  local path=$1 args=(); shift
  for pair in "$@"; do args+=(--data-urlencode "$pair"); done
  curl -s -o /dev/null -w '%{http_code}' -X POST "${args[@]}" "${url%/}$path"
}
finish() { wait "$pid"; status=$?; pid=""; }
same=(text.0="First line
second line" text.1=Other comment.0= comment.1= approve.0=on mark.0="~" field.0="was slow")

cp "$scratch/template.md" "$scratch/a.md"
start "$scratch/a.md"
html=$(curl -s "$url")
code=$(post /done "${same[@]/comment.1=/comment.1=Make it shorter}")
finish
check "a comment lands as a Comment line under its section's block, and only there" \
  '[ "$code" = 200 ] && [ "$status" = 0 ] && [ "$(grep -c "^Comment:" "$scratch/a.md")" = 1 ] && [ "$(grep -A2 -x "Other" "$scratch/a.md" | tail -1)" = "Comment: Make it shorter" ]'
check "a ticked box and a non-blank mark start checked on the page" \
  'grep -q "type=checkbox name=\"approve.0\" checked" <<<"$html" && grep -q "name=\"mark.0\" value=\"~\" checked" <<<"$html"'
check "text shows escaped, never as markup" \
  'grep -q "First line" <<<"$html" && ! grep -q "<b>" <<<"$html"'

cp "$scratch/template.md" "$scratch/b.md"
start "$scratch/b.md"
code=$(post /done text.0=$'First line\r\nsecond line\r\n' text.1=Other comment.0= comment.1= approve.0=on mark.0=bogus field.0="was slow")
finish
check "a browser's CRLF and trailing newline, and a mark that isn't one, change nothing" \
  '[ "$code" = 200 ] && cmp -s "$scratch/template.md" "$scratch/b.md"'

cp "$scratch/template.md" "$scratch/c.md"
start "$scratch/c.md"
code=$(post /done "${same[@]/approve.0=on/approve.0=}" )
finish
check "the box stays ticked while the form sends it" '[ "$code" = 200 ] && cmp -s "$scratch/template.md" "$scratch/c.md"'

cp "$scratch/template.md" "$scratch/d.md"
start "$scratch/d.md"
wrong=$(post /elsewhere "${same[@]}")
{ printf 'text.0='; head -c 34000000 /dev/zero | tr '\0' 'x'; } >"$scratch/huge"
big=$(curl -s -o "$scratch/big.body" -w '%{http_code}' -X POST --data-binary "@$scratch/huge" "${url%/}/done")
check "an answer over 32 MB is refused once, with a page that says so" '[ "$big" = 413 ] && grep -q "Too large" "$scratch/big.body" && ! grep -q "Not taken" "$scratch/big.body" && ! grep -q xxxxxxxx "$scratch/d.md"'
kill -0 "$pid" 2>/dev/null && alive=yes || alive=no
code=$(post /done text.0=Changed text.1=Other comment.0= comment.1= mark.0=x field.0=)
again=$(post /done text.0=Again)
finish
check "a post to another path is refused and the page stays open" '[ "$wrong" = 400 ] && [ "$alive" = yes ]'
check "an untick, a mark and an emptied note are written back" \
  '[ "$code" = 200 ] && grep -qx "Changed" "$scratch/d.md" && grep -qx -- "- \[ \] approve" "$scratch/d.md" && grep -q "^1\. \[x\] Try it" "$scratch/d.md" && grep -qx "   notes:" "$scratch/d.md"'
check "a second Done changes nothing" '[ "$again" != 200 ] && ! grep -qx "Again" "$scratch/d.md"'

cp "$scratch/template.md" "$scratch/e.md"
start "$scratch/e.md" 1
finish
check "no answer before the timeout exits 2 and leaves the file as it was" '[ "$status" = 2 ] && cmp -s "$scratch/template.md" "$scratch/e.md"'

printf '## Empty\nx:1\n\n```text\n```\n\n## Trailing\ny:1\n\n```text\nline\n\n```\n' >"$scratch/edge.template"
cp "$scratch/edge.template" "$scratch/f.md"
start "$scratch/f.md"
code=$(post /done text.0= text.1=$'line\n\n' comment.0= comment.1=)
finish
check "an empty block and a block ending in a blank line come back byte for byte when left alone" \
  '[ "$code" = 200 ] && cmp -s "$scratch/edge.template" "$scratch/f.md"'

cp "$scratch/template.md" "$scratch/g.md"
start "$scratch/g.md"
cross=$(curl -s -o /dev/null -w '%{http_code}' -X POST -H "Origin: https://elsewhere.example" --data-urlencode text.0=Hijacked "${url%/}/done")
renamed=$(curl -s -o /dev/null -w '%{http_code}' -X POST -H "Host: attacker.example" --data-urlencode text.0=Hijacked "${url%/}/done")
own_args=(); for pair in "${same[@]}"; do own_args+=(--data-urlencode "$pair"); done
own=$(curl -s -o /dev/null -w '%{http_code}' -X POST -H "Origin: ${url%/}" "${own_args[@]}" "${url%/}/done")
finish
check "a post from another web page, or under another host name, is refused; the page's own post is taken" \
  '[ "$cross" = 400 ] && [ "$renamed" = 400 ] && [ "$own" = 200 ] && ! grep -q Hijacked "$scratch/g.md"'

printf '# Q\n\n## Q1: Colour?\n- (x) red\n- ( ) blue\n\n## Q2: Size?\n- ( ) small\n- (x) large\n' >"$scratch/q.template"
cp "$scratch/q.template" "$scratch/h.md"
start "$scratch/h.md"
html=$(curl -s "$url")
code=$(post /done choice.1=small note="Looks good")
finish
check "each run of options is its own question, a question left alone keeps its pick, and the page-end comment lands under Anything else" \
  '[ "$code" = 200 ] && grep -q "name=\"choice.1\" value=\"small\"" <<<"$html" && grep -q "name=\"choice.0\" value=\"red\" checked" <<<"$html" && grep -q "name=\"note\"" <<<"$html" && grep -qx -- "- (x) red" "$scratch/h.md" && grep -qx -- "- (x) small" "$scratch/h.md" && grep -qx -- "- ( ) large" "$scratch/h.md" && [ "$(tail -n 2 "$scratch/h.md")" = "## Anything else
Comment: Looks good" ] && [ -z "$(tail -c 1 "$scratch/h.md")" ]'

cp "$scratch/template.md" "$scratch/i.md"
start "$scratch/i.md"
negative=$(curl -s -o /dev/null -w '%{http_code}' -m 5 -X POST -H "Content-Length: -1" "${url%/}/done")
code=$(post /done text.0=$'Before\n```\nAfter' text.1=Other comment.0= comment.1= approve.0=on mark.0="~" field.0="was slow")
finish
check "a negative length is refused, and a typed fence line can't close its block early" \
  '[ "$negative" = 400 ] && [ "$code" = 200 ] && grep -qx " \`\`\`" "$scratch/i.md" && [ "$(grep -A3 -x "Before" "$scratch/i.md" | tail -1)" = "\`\`\`" ]'

mkdir -p "$scratch/sub"; echo '<svg id=c></svg>' >"$scratch/c.svg"; echo '<svg id=d></svg>' >"$scratch/sub/d.svg"
printf '# Plan\n\n![Here](c.svg)\n![Deeper](sub/d.svg)\n- [ ] K-1 star: one\n' >"$scratch/j.template"
cp "$scratch/j.template" "$scratch/j.md"
start "$scratch/j.md"
html=$(curl -s "$url")
code=$(post /done)
finish
check "a chart line comes back as written, a chart outside the page's folder stays text, and an unticked box shows unticked" \
  '[ "$code" = 200 ] && grep -q "<svg id=c>" <<<"$html" && ! grep -q "<svg id=d>" <<<"$html" && grep -qF "![Deeper](sub/d.svg)" <<<"$html" && grep -qF "type=checkbox name=\"box.0\"> K-1 star: one" <<<"$html" && cmp -s "$scratch/j.template" "$scratch/j.md"'

printf '# Q\n\n## Q1: Which?\n- (x) One\n- ( ) Two\n- ( ) Other\n   notes:\n' >"$scratch/k.md"
start "$scratch/k.md"
port=${url##*:}; port=${port%/}
bound=$(ss -ltnH "sport = :$port" 2>/dev/null | awk '{print $4}')
code=$(post /done choice.0=Other field.0="Neither, ask me later")
finish
check "choosing Other with a note brings back Other and the note, and the page listens on this machine only" \
  '[ "$code" = 200 ] && grep -qx -- "- (x) Other" "$scratch/k.md" && grep -qx -- "- ( ) One" "$scratch/k.md" && grep -qx "   notes: Neither, ask me later" "$scratch/k.md" && [ "$bound" = "127.0.0.1:$port" ]'

printf '## A\na:1\n- [ ] approve\n' >"$scratch/one-box.md"
printf '## A\na:1\n- [ ] approve\n\n## B\nb:1\n- [ ] approve\n' >"$scratch/two-box.md"
start "$scratch/one-box.md"; one_box=$(curl -s "$url"); post /done >/dev/null; finish
start "$scratch/two-box.md"; two_box=$(curl -s "$url"); post /done >/dev/null; finish
printf '## A\na:1\n\n```text\nA\n```\n' >"$scratch/no-box.md"
start "$scratch/no-box.md"; no_box=$(curl -s "$url"); post /done >/dev/null; finish
check "approve all shows on a page with one approve box and on a page with two, and not on a page with none" \
  'grep -q "name=\"approve_all\"" <<<"$two_box" && grep -q "name=\"approve_all\"" <<<"$one_box" && ! grep -q "name=\"approve_all\"" <<<"$no_box"'
printf '## A\na:1\n- [ ] approve\n' >"$scratch/one-tick.md"
start "$scratch/one-tick.md"; post /done approve_all=on >/dev/null; finish
check "approve all on a page with one approve box brings that box back approved" \
  'grep -qx -- "- \[x\] approve" "$scratch/one-tick.md"'

printf '# Plan\n\n## Course\n- [ ] K-1 one\n- [ ] K-2 two\n\n## Questions\n- ( ) A\n\n## Sign-off\na:1\n- [ ] approve\n' >"$scratch/ticks.md"
start "$scratch/ticks.md"; ticks=$(curl -s "$url"); post /done box.0=on box.1=on approve.0=on >/dev/null; finish
printf '# Plan\n\n## Course\n- [x] K-1 one\n- [x] K-2 two\n\n## Questions\n- ( ) A\n\n## Sign-off\na:1\n- [x] approve\n' >"$scratch/ticks.want"
tick_btns=$(grep -c 'onclick="tick(this,true)">Tick all' <<<"$ticks")
check "a heading that holds boxes gets Tick all and Untick all, one that holds none gets neither, and the page gets one pair beside Done" \
  '[ "$tick_btns" = 3 ] && [ "$(grep -c "Untick all" <<<"$ticks")" = 3 ] && grep -q "</h2>.<p class=tick>" <<<"$(tr "\n" "." <<<"$ticks")" && ! grep -A1 "<h2>Questions</h2>" <<<"$ticks" | grep -q tick && grep -q "<span class=tick data-page=1>.*Done" <<<"$ticks" && ! grep -q "Tick all" <<<"$no_box"'
check "every box ticked as the buttons leave the form comes back as if each were ticked by hand" 'cmp -s "$scratch/ticks.want" "$scratch/ticks.md"'

# tick() runs in node against a stand-in page, since the markup checks above
# cannot see what a click does.
PYTHONPATH="$(dirname "$page")" python3 -c 'import page; print(page.TICK_JS)' >"$scratch/tick.js"
tick_run=$(node - "$scratch/tick.js" <<'JS' 2>&1
const fs = require("fs");
function el(tag, kids = [], props = {}) {
  const n = { tagName: tag, children: kids, dataset: {}, ...props };
  kids.forEach((k, i) => { k.parentNode = n; k.nextElementSibling = kids[i + 1] || null; });
  n.querySelectorAll = () => kids.flatMap(k => (k.tagName === "INPUT" ? [k] : []).concat(k.querySelectorAll()));
  return n;
}
const box = name => el("INPUT", [], { type: "checkbox", name, checked: false });
const b0 = box("box.0"), b1 = box("box.1"), radio = el("INPUT", [], { type: "radio", name: "choice.0", checked: false });
const ap = box("approve.0"), all = box("approve_all");
const course = el("P"), signoff = el("P"), page = el("SPAN");
page.dataset.page = "1";
const form = el("FORM", [el("H2"), course, el("LABEL", [b0]), el("LABEL", [b1]), el("H2"), el("LABEL", [radio]),
  el("H2"), signoff, el("LABEL", [ap]), el("P", [el("LABEL", [all]), page])]);
form.elements = { approve_all: all };
globalThis.document = { forms: [form] };
eval(fs.readFileSync(process.argv[2], "utf8") + ";globalThis.tick=tick");
const state = () => [b0, b1, radio, ap, all].map(i => +i.checked).join("");
const btn = p => ({ parentNode: p });
const out = [];
tick(btn(course), true); out.push(state());
tick(btn(course), false); out.push(state());
tick(btn(signoff), true); out.push(state());
tick(btn(signoff), false); out.push(state());
tick(btn(page), true); out.push(state());
all.checked = true; tick(btn(page), false); out.push(state());
console.log(out.join(" "));
JS
)
check "Tick all under a heading ticks only its boxes, the page pair ticks every box but leaves approve all, and Untick all clears approve all too" \
  '[ "$tick_run" = "11000 00000 00010 00000 11010 00000" ]'

printf '#!/usr/bin/env bash\necho "${LD_LIBRARY_PATH-unset}" >"%s/libpath"\necho "$1" >"%s/url"\n' "$scratch" "$scratch" >"$scratch/env-browser"
chmod +x "$scratch/env-browser"
cp "$scratch/template.md" "$scratch/e.md"
cp "$scratch/browser" "$scratch/plain-browser"; cp "$scratch/env-browser" "$scratch/browser"
mkdir -p "$scratch/nosession" "$scratch/session"
printf '#!/usr/bin/env bash\nexit 1\n' >"$scratch/nosession/systemctl"
cat >"$scratch/session/systemctl" <<'EOF'
#!/usr/bin/env bash
echo "PATH=$PATH"
echo "DESKTOP_ONLY=from-the-desktop"
echo "ODD=\$'a\\nb'"
EOF
chmod +x "$scratch/nosession/systemctl" "$scratch/session/systemctl"
PATH="$scratch/nosession:$PATH" LD_LIBRARY_PATH=/stale/dev-shell/lib start "$scratch/e.md"; post /done >/dev/null; finish
check "with no desktop session to read, a dev shell's LD_LIBRARY_PATH still stays out of the browser the page starts" \
  '[ "$(cat "$scratch/libpath" 2>/dev/null)" = unset ]'
printf '#!/usr/bin/env bash\necho "${DESKTOP_ONLY-unset} ${DEV_ONLY-unset} ${LD_LIBRARY_PATH-unset} ${ODD-unset}" >"%s/libpath"\necho "$1" >"%s/url"\n' "$scratch" "$scratch" >"$scratch/browser"
cp "$scratch/template.md" "$scratch/e.md"
PATH="$scratch/session:$PATH" DEV_ONLY=dev LD_LIBRARY_PATH=/stale/dev-shell/lib start "$scratch/e.md"; post /done >/dev/null; finish
check "the browser gets the desktop session's environment, with nothing the dev shell added, and an escaped value skipped" \
  '[ "$(cat "$scratch/libpath" 2>/dev/null)" = "from-the-desktop unset unset unset" ]'
cp "$scratch/plain-browser" "$scratch/browser"

python3 -I "$page" 2>"$scratch/usage" >/dev/null; none=$?
python3 -I "$page" a b >/dev/null 2>&1; two=$?
check "no file, or two, is a usage error that says how to call it" '[ "$none" = 2 ] && [ "$two" = 2 ] && grep -qx "Usage: page.py <file.md> \[--timeout SECONDS\]" "$scratch/usage"'
# A checklist draws as cards, with Markdown drawn and the legend as mark labels.
cat >"$scratch/cards.md" <<'MD'
# Over to you, Bob!

Open `the client` and **look**.
signed off: nothing yet
proven by: `health.sh` answers ok
Mark each item: [x] completed as expected, [~] completed with changes, [-] failed to complete, [ ] not tested at all.

## Pack

1. [ ] Spawn `i_paper` → the *sheet* shows
   person: real client
   kit: `/runscript paper`
   notes:

quick notes:
- BUG:
- IDEA: later
MD
render() { python3 -I -c 'import sys; sys.path.insert(0, sys.argv[1]); import page; print(page.page("x", page.parse(sys.stdin.read(), "/")))' "$(dirname "$page")"; }
html=$(render <"$scratch/cards.md")
check "inline code, bold and italics draw as Markdown" 'grep -q "<code>the client</code>" <<<"$html" && grep -q "<strong>look</strong>" <<<"$html" && grep -q "<em>sheet</em>" <<<"$html" && ! grep -q "\`" <<<"$html"'
check "an item is a card with its action, expected result and meta lines" 'grep -q "<div class=card><div class=act>1. Spawn <code>i_paper</code></div>" <<<"$html" && grep -q "<div class=exp>→ the <em>sheet</em> shows</div>" <<<"$html" && grep -q "<div class=meta>kit: <code>/runscript paper</code></div>" <<<"$html"'
check "the legend becomes the mark labels and leaves the page body" 'grep -q "value=\"x\"> completed as expected</label>" <<<"$html" && ! grep -q "Mark each item" <<<"$html" && ! grep -qF "[x]" <<<"$html"'
# The page owns the four labels: a hand-typed legend that drops one still
# shows all four, and a checklist with no legend at all shows them too.
html=$(sed 's/\[-\] failed to complete/[ ] failed to complete/' "$scratch/cards.md" | render)
check "a legend typed wrong still labels every mark" 'grep -q "value=\"-\"> failed to complete</label>" <<<"$html" && grep -q "value=\" \"[^>]*> not tested at all</label>" <<<"$html" && ! grep -q "Mark each item" <<<"$html"'
html=$(grep -v "^Mark each item" "$scratch/cards.md" | render)
check "a checklist with no legend still labels every mark" 'grep -q "value=\"~\"> completed with changes</label>" <<<"$html" && ! grep -qF "[-]" <<<"$html"'
html=$(render <"$scratch/cards.md")
check "signed off and proven by fold into one collapsed header" '[ "$(grep -c "<summary>Signed off and proven by" <<<"$html")" = 1 ] && grep -q "<code>health.sh</code>" <<<"$html"'
check "quick notes fold into a block that opens when a note is filled" 'grep -q "<details class=quick open><summary>Quick notes" <<<"$html" && grep -q "IDEA: <input type=text name=\"field.2\" value=\"later\">" <<<"$html"'
blank=$(sed 's/^- IDEA: later$/- IDEA:/' "$scratch/cards.md" | render)
check "a quick-notes block with no note stays closed" 'grep -q "<details class=quick><summary>" <<<"$blank"'
check "a no-op Done writes the checklist back byte for byte" 'python3 -I -c "import sys; sys.path.insert(0, sys.argv[1]); import page; t=open(sys.argv[2]).read(); sys.exit(page.answered(page.parse(t, \"/\"), {}) != t)" "$(dirname "$page")" "$scratch/cards.md"'
# A sketch written with no final newline glues the closing fence to its last
# line. The page splits it off, so each block holds only its own XML.
printf '# Sketch\n\n```drawio\n<mxfile>a</mxfile>```\n\n## Two\n\n```drawio\n<mxfile>b</mxfile>\n```\n' >"$scratch/glued.md"
unglued=$(python3 -I -c "import sys; sys.path.insert(0, sys.argv[1]); import page; print(page.unglue(open(sys.argv[2]).read()), end='')" "$(dirname "$page")" "$scratch/glued.md")
check "a fence glued to a sketch's last line closes that sketch, and only it" \
  '[ "$unglued" = "$(printf "# Sketch\n\n\`\`\`drawio\n<mxfile>a</mxfile>\n\`\`\`\n\n## Two\n\n\`\`\`drawio\n<mxfile>b</mxfile>\n\`\`\`\n")" ]'
# The page's own markup, byte for byte, for a document that uses every part:
# each close of a card or quick-notes block, and each mark of a drawing.
cat >"$scratch/view.py" <<'PY'
import os, sys
sys.path.insert(0, sys.argv[1])
import page
if len(sys.argv) > 3:
    os.environ["DRAWIO_HOME"] = sys.argv[3]
else:
    os.environ.pop("DRAWIO_HOME", None)
text = open(sys.argv[2]).read()
out = page.page("x", page.parse(text, os.path.dirname(os.path.abspath(sys.argv[2]))))
print(out[out.index(page.DRAWING_JS) + len(page.DRAWING_JS) + len("</script>\n"):])
PY
cat >"$scratch/doc.md" <<'MD'
# Title
Mark each item: [x] completed as expected, [~] completed with changes, [-] failed to complete, [ ] not tested at all.
signed off: nobody
between the two
proven by: nothing

1. [ ] First `a` → shows
   person: me
2. [x] Second
Plain right after a card
3. [ ] Third → ok
4. [ ] Fourth

- [x] boxed after a blank
5. [ ] Fifth
quick notes:
- BUG: found
5. [ ] Sixth
## Heading after a card
   person: stray
- [ ] approve
- [x] a box _with_ style
![Chart](c.svg)
1. [ ] Seventh
```text
l1
l2
l3
l4
l5
```
## Choose
- (x) red
- ( ) blue
quick notes:
- IDEA:
- RULE: later
MD
cat >"$scratch/doc.golden" <<'MD'
<h1>Title</h1>
<p class=tick><button type=button onclick="tick(this,true)">Tick all</button> <button type=button onclick="tick(this,false)">Untick all</button></p>
<details><summary>Signed off and proven by</summary><p class=text>signed off: nobody</p><p class=text>proven by: nothing</p></details>
<p class=text>between the two</p>
<div class=card><div class=act>1. First <code>a</code></div>
<div class=exp>→ shows</div>
<div class=marks><label><input type=radio name="mark.0" value="x"> completed as expected</label><label><input type=radio name="mark.0" value="~"> completed with changes</label><label><input type=radio name="mark.0" value="-"> failed to complete</label><label><input type=radio name="mark.0" value=" " checked> not tested at all</label></div>
<div class=meta>person: me</div>
</div>
<div class=card><div class=act>2. Second</div>
<div class=marks><label><input type=radio name="mark.1" value="x" checked> completed as expected</label><label><input type=radio name="mark.1" value="~"> completed with changes</label><label><input type=radio name="mark.1" value="-"> failed to complete</label><label><input type=radio name="mark.1" value=" "> not tested at all</label></div>
</div>
<p class=text>Plain right after a card</p>
<div class=card><div class=act>3. Third</div>
<div class=exp>→ ok</div>
<div class=marks><label><input type=radio name="mark.2" value="x"> completed as expected</label><label><input type=radio name="mark.2" value="~"> completed with changes</label><label><input type=radio name="mark.2" value="-"> failed to complete</label><label><input type=radio name="mark.2" value=" " checked> not tested at all</label></div>
</div>
<div class=card><div class=act>4. Fourth</div>
<div class=marks><label><input type=radio name="mark.3" value="x"> completed as expected</label><label><input type=radio name="mark.3" value="~"> completed with changes</label><label><input type=radio name="mark.3" value="-"> failed to complete</label><label><input type=radio name="mark.3" value=" " checked> not tested at all</label></div>
</div>
<label><input type=checkbox name="box.0" checked> boxed after a blank</label><br>
<div class=card><div class=act>5. Fifth</div>
<div class=marks><label><input type=radio name="mark.4" value="x"> completed as expected</label><label><input type=radio name="mark.4" value="~"> completed with changes</label><label><input type=radio name="mark.4" value="-"> failed to complete</label><label><input type=radio name="mark.4" value=" " checked> not tested at all</label></div>
</div>
<details class=quick open><summary>Quick notes: BUG, QUIRK, FRICTION, UGLY, IDEA, RULE, WIP, QUESTION</summary>
<label>BUG: <input type=text name="field.0" value="found"></label>
</details>
<div class=card><div class=act>5. Sixth</div>
<div class=marks><label><input type=radio name="mark.5" value="x"> completed as expected</label><label><input type=radio name="mark.5" value="~"> completed with changes</label><label><input type=radio name="mark.5" value="-"> failed to complete</label><label><input type=radio name="mark.5" value=" " checked> not tested at all</label></div>
</div>
<h2>Heading after a card</h2>
<p class=tick><button type=button onclick="tick(this,true)">Tick all</button> <button type=button onclick="tick(this,false)">Untick all</button></p>
<p class=text>   person: stray</p>
<label><input type=checkbox name="approve.0"> approve</label>
<label><input type=checkbox name="box.1" checked> a box <em>with</em> style</label><br>
<div class=chart onclick="zoom(this)"><svg id=c></svg>
</div>
<div class=card><div class=act>1. Seventh</div>
<div class=marks><label><input type=radio name="mark.6" value="x"> completed as expected</label><label><input type=radio name="mark.6" value="~"> completed with changes</label><label><input type=radio name="mark.6" value="-"> failed to complete</label><label><input type=radio name="mark.6" value=" " checked> not tested at all</label></div>
<textarea name="text.0" rows="6">l1
l2
l3
l4
l5</textarea>
</div>
<textarea name="comment.0" placeholder="Comment"></textarea>
<h2>Choose</h2>
<label><input type=radio name="choice.0" value="red" checked> red</label><br>
<label><input type=radio name="choice.0" value="blue"> blue</label><br>
<details class=quick open><summary>Quick notes: BUG, QUIRK, FRICTION, UGLY, IDEA, RULE, WIP, QUESTION</summary>
<label>IDEA: <input type=text name="field.1" value=""></label>
<label>RULE: <input type=text name="field.2" value="later"></label>
</details>
<h2>Anything else</h2><textarea name="note" placeholder="Comment"></textarea>
<p><label><input type=checkbox name="approve_all"> approve all</label> <span class=tick data-page=1><button type=button onclick="tick(this,true)">Tick all</button> <button type=button onclick="tick(this,false)">Untick all</button></span> <button type=submit>Done</button></p></form>
MD
dir=$(dirname "$page")
python3 -I "$scratch/view.py" "$dir" "$scratch/doc.md" >"$scratch/doc.out"
check "a page with every part draws its exact markup, each card and quick-notes block closed where it ends" 'cmp -s "$scratch/doc.out" "$scratch/doc.golden"'
printf '```drawio\n<a/>\n```\n\n## Two\n\n```drawio\n<b/>\n```\n' >"$scratch/draw.md"
mkdir -p "$scratch/dio"; echo '<html/>' >"$scratch/dio/index.html"
cat >"$scratch/draw-canvas.golden" <<'MD'
<script>frames[0]=1</script><iframe id="dio0" src="/drawio/index.html?embed=1&proto=json&spin=1&stealth=1&offline=1&noExitBtn=1&noSaveBtn=1&saveAndExit=0" style="width:100%;height:80vh;border:1px solid #8886"></iframe><input type=hidden name="drawing_xml.0" value="&lt;a/&gt;"><input type=hidden name="drawing_png.0" value="">
<h2>Two</h2>
<script>frames[1]=1</script><iframe id="dio1" src="/drawio/index.html?embed=1&proto=json&spin=1&stealth=1&offline=1&noExitBtn=1&noSaveBtn=1&saveAndExit=0" style="width:100%;height:80vh;border:1px solid #8886"></iframe><input type=hidden name="drawing_xml.1" value="&lt;b/&gt;"><input type=hidden name="drawing_png.1" value="">
<h2>Anything else</h2><textarea name="note" placeholder="Comment"></textarea>
<p><button type=submit>Done</button></p></form>
MD
cat >"$scratch/draw-text.golden" <<'MD'
<textarea name="drawing_xml.0" rows="8">&lt;a/&gt;</textarea>
<h2>Two</h2>
<textarea name="drawing_xml.1" rows="8">&lt;b/&gt;</textarea>
<h2>Anything else</h2><textarea name="note" placeholder="Comment"></textarea>
<p><button type=submit>Done</button></p></form>
MD
python3 -I "$scratch/view.py" "$dir" "$scratch/draw.md" "$scratch/dio" >"$scratch/draw-canvas.out"
python3 -I "$scratch/view.py" "$dir" "$scratch/draw.md" >"$scratch/draw-text.out"
mkdir -p "$scratch/empty-app"
python3 -I "$scratch/view.py" "$dir" "$scratch/draw.md" "$scratch/empty-app" >"$scratch/draw-empty.out"
check "a drawing is an app frame where the draw.io app is there, and its XML as text where it is not or its folder has no app" \
  'cmp -s "$scratch/draw-canvas.out" "$scratch/draw-canvas.golden" && cmp -s "$scratch/draw-text.out" "$scratch/draw-text.golden" && cmp -s "$scratch/draw-empty.out" "$scratch/draw-text.golden"'

# parse, unglue and answered, part by part.
cat >"$scratch/unit.py" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import page
bad = 0
def eq(name, got, want):
    global bad
    if got != want:
        bad = 1
        print("FAIL", name, repr(got), "wanted", repr(want))
text = "```text\na\n```\n```drawio\n<x/>\n<y/>\n```\n```text\nb\n```\ntail"
eq("parse", page.parse(text, "/"), [
    ("line", "```text"), ("block", ["a"]), ("line", "```"), ("comment",),
    ("line", "```drawio"), ("drawing", ["<x/>", "<y/>"]), ("line", "```"),
    ("line", "```text"), ("block", ["b"]), ("line", "```"), ("comment",),
    ("line", "tail")])
eq("parse open drawing", page.parse("```drawio\n<x/>", "/"), [("line", "```drawio"), ("drawing", ["<x/>"])])
eq("fence_end", page.fence_end(["```", "```drawio", "<x/>", "```"], 1), 3)
eq("fence_end open", page.fence_end(["```drawio", "<x/>"], 0), 2)
glued = "```drawio\n<a>\n<b>```\n\nplain```\n```drawio\n<c>\n```\nafter```\n```text\nabc```\n"
want = "```drawio\n<a>\n<b>\n```\n\nplain```\n```drawio\n<c>\n```\nafter```\n```text\nabc```\n"
eq("unglue", page.unglue(glued), want)
eq("unglue plain", page.unglue("# T\nfoo```\n"), "# T\nfoo```\n")
parts = page.parse("```drawio\n<a/>\n```\n```text\nt\n```\n", "/")
eq("picture once, after the closing fence",
   page.answered(parts, {"drawing_png_file.0": ["p.png"]}),
   "```drawio\n<a/>\n```\n![drawing 0](p.png)\n```text\nt\n```\n")
eq("note after a last line with text", page.answered(page.parse("## A\nx", "/"), {"note": ["n"]}),
   "## A\nx\n\n## Anything else\nComment: n")
eq("note on nothing", page.answered([], {"note": ["n"]}), "\n## Anything else\nComment: n")
sys.exit(bad)
PY
python3 -I "$scratch/unit.py" "$dir" >"$scratch/unit.out" 2>&1; unit=$?
check "parse, unglue and answered keep each block, fence, picture and note where it belongs" '[ "$unit" = 0 ]'
[ "$unit" = 0 ] || cat "$scratch/unit.out"

# The draw.io app's files are served from its own folder, and nothing outside it.
mkdir -p "$scratch/app/sub"; printf JS >"$scratch/app/app.js"; printf INDEX >"$scratch/app/index.html"; printf BIN >"$scratch/app/data.bin"
echo secret >"$scratch/outside.txt"
printf '```drawio\n<a/>\n```\n\n## Two\n\n```drawio\n<b/>\n```\n\n```text\nt\n```\n' >"$scratch/m.md"
DRAWIO_HOME="$scratch/app" start "$scratch/m.md"
base=${url%/}
curl -s -D "$scratch/hdr.page" -o /dev/null "$base/"
curl -s -D "$scratch/hdr.js" -o "$scratch/body.js" "$base/drawio/app.js?v=1"
curl -s -D "$scratch/hdr.bin" -o "$scratch/body.bin" "$base/drawio/data.bin"
root=$(curl -s "$base/drawio/")
missing=$(curl -s -w '|%{http_code}' "$base/drawio/nope.js")
folder=$(curl -s -o /dev/null -w '%{http_code}' "$base/drawio/sub")
escape=$(curl -s --path-as-is -w '|%{http_code}' "$base/drawio/../outside.txt")
check "the page is served as UTF-8 HTML, and a draw.io file as its own type, once, with nothing after it" \
  'grep -qi "^content-type: text/html; charset=utf-8" "$scratch/hdr.page" && grep -qi "^content-type: text/javascript" "$scratch/hdr.js" && [ "$(cat "$scratch/body.js")" = JS ] && grep -qi "^content-type: application/octet-stream" "$scratch/hdr.bin" && [ "$(cat "$scratch/body.bin")" = BIN ]'
check "the draw.io folder's own address gives its index, and a missing file, a folder or a path out of it is 404" \
  '[ "$root" = INDEX ] && [ "$missing" = "Not found.|404" ] && [ "$folder" = 404 ] && [ "${escape#*|}" = 404 ] && ! grep -q secret <<<"$escape"'
kept=$(curl -s -w '|%{http_code}' -X POST --data-urlencode xml='<new/>' "$base/drawing/1")
live=$(cat "$scratch/m.md")
post /done text.0=t comment.0= >/dev/null
finish
check "a live drawing change is kept at once in its own block, answers Kept. once, and survives Done" \
  '[ "$kept" = "Kept.|200" ] && [ "$live" = "$(cat "$scratch/m.md")" ] && [ "$(cat "$scratch/m.md")" = "$(printf "\`\`\`drawio\n<a/>\n\`\`\`\n\n## Two\n\n\`\`\`drawio\n<new/>\n\`\`\`\n\n\`\`\`text\nt\n\`\`\`\n")" ]'

# A fence glued to a sketch's last line is fixed in the file at once, and the
# page is drawn from the fixed text.
printf '# Sketch\n\n```drawio\n<mxfile>a</mxfile>```\n\n## Two\n\n```drawio\n<mxfile>b</mxfile>\n```\n' >"$scratch/gl.md"
cp "$scratch/gl.md" "$scratch/gl2.md"
fixed_text=$(printf '# Sketch\n\n```drawio\n<mxfile>a</mxfile>\n```\n\n## Two\n\n```drawio\n<mxfile>b</mxfile>\n```\n')
DRAWIO_HOME="" start "$scratch/gl.md"
html=$(curl -s "$url")
post /done "drawing_xml.0=<mxfile>a</mxfile>" "drawing_xml.1=<mxfile>b</mxfile>" >/dev/null
finish
DRAWIO_HOME="" start "$scratch/gl2.md" 1
finish
check "a glued fence is split in the file, even with no answer, and the page shows each sketch on its own" \
  '[ "$(grep -c "name=\"drawing_xml\." <<<"$html")" = 2 ] && [ "$(cat "$scratch/gl.md")" = "$fixed_text" ] && [ "$status" = 2 ] && [ "$(cat "$scratch/gl2.md")" = "$fixed_text" ]'

# A drawing's picture is saved beside the file and named after its closing fence.
printf '```drawio\n<a/>\n```\n\n```text\nt\n```\n' >"$scratch/png.md"
DRAWIO_HOME="" start "$scratch/png.md"
post /done drawing_xml.0='<a/>' drawing_png.0='data:image/png;base64,aGk=' text.0=t comment.0= >/dev/null
finish
check "a drawing's PNG is saved as <file>.drawing-<n>.png and named once, after its closing fence" \
  '[ "$(cat "$scratch/png.drawing-0.png" 2>/dev/null)" = hi ] && [ "$(cat "$scratch/png.md")" = "$(printf "\`\`\`drawio\n<a/>\n\`\`\`\n![drawing 0](png.drawing-0.png)\n\n\`\`\`text\nt\n\`\`\`\n")" ]'

# What the page says on stderr, with a browser that opens and with none.
cp "$scratch/template.md" "$scratch/s.md"
BROWSER="$scratch/browser" timeout 30 python3 -I "$page" "$scratch/s.md" --timeout 1 2>"$scratch/err.open"; st_open=$?
bare="$scratch/bare"; mkdir -p "$bare"
for tool in python3 bash; do ln -sf "$(command -v "$tool")" "$bare/$tool"; done
timeout 30 env -u BROWSER -u DISPLAY -u WAYLAND_DISPLAY PATH="$bare" python3 -I "$page" "$scratch/s.md" --timeout 1 2>"$scratch/err.none"; st_none=$?
check "the page names its address on stderr, and says no browser opened only when none did" \
  '[ "$st_open" = 2 ] && grep -q "^page: open http://127.0.0.1:[0-9]*/$" "$scratch/err.open" && ! grep -q "no browser opened" "$scratch/err.open" && grep -q "^page: no browser opened; give the user http://127.0.0.1:[0-9]*/$" "$scratch/err.none"'
# With no systemctl at all, a dev shell's LD_LIBRARY_PATH still stays out of the browser.
cp "$scratch/env-browser" "$scratch/browser"
cp "$scratch/template.md" "$scratch/e.md"
PYPATH="$bare" LD_LIBRARY_PATH=/stale/dev-shell/lib start "$scratch/e.md"; post /done >/dev/null; finish
check "with no systemctl to run, a dev shell's LD_LIBRARY_PATH still stays out of the browser the page starts" \
  '[ "$(cat "$scratch/libpath" 2>/dev/null)" = unset ]'
cp "$scratch/plain-browser" "$scratch/browser"

# The server stops answering once the page has its answer.
cat >"$scratch/late.py" <<'PY'
import sys, threading, urllib.request, webbrowser
sys.path.insert(0, sys.argv[1])
import page
page.use_desktop_env = lambda: None
def fake_open(url):
    def run():
        urllib.request.urlopen(url, timeout=5).read()
        urllib.request.urlopen(urllib.request.Request(url + "done", data=b"a=1", method="POST"), timeout=5).read()
    threading.Thread(target=run, daemon=True).start()
    seen["url"] = url
    return True
seen = {}
webbrowser.open = fake_open
got = page.serve_form(b"<p>x</p>", "/done", lambda body: None, 10)
try:
    urllib.request.urlopen(seen["url"], timeout=2).read()
    print("answered after Done")
except OSError:
    print("silent after Done", got)
PY
check "after Done the page serves nothing more" '[ "$(timeout 30 python3 -I "$scratch/late.py" "$dir" 2>/dev/null)" = "silent after Done True" ]'
# EVAL_PAGE_DISPLAY=1 opens the page with no display, so an eval can read its link; unset, the editor opens.
printf '# Drafts\n\n## Tip\n\ntext\n' > "$scratch/evalpage.md"
# The page waits for Done, so stop it once its link is out.
timeout 15 env -u DISPLAY -u WAYLAND_DISPLAY -u BROWSER EVAL_PAGE_DISPLAY=1 bash "$dir/open-page.sh" "$scratch/evalpage.md" > "$scratch/evalpage.on" 2>&1 &
onpid=$!
for _ in $(seq 50); do grep -q "page: open" "$scratch/evalpage.on" && break; sleep 0.2; done
kill "$onpid" 2>/dev/null; wait "$onpid" 2>/dev/null
timeout 15 env -u DISPLAY -u WAYLAND_DISPLAY -u EVAL_PAGE_DISPLAY VISUAL=true bash "$dir/open-page.sh" "$scratch/evalpage.md" > "$scratch/evalpage.off" 2>&1
timeout 15 env -u DISPLAY -u WAYLAND_DISPLAY EVAL_PAGE_DISPLAY=0 VISUAL=true bash "$dir/open-page.sh" "$scratch/evalpage.md" > "$scratch/evalpage.zero" 2>&1
check "EVAL_PAGE_DISPLAY=0 opens the editor, not the page" 'grep -q "draft: wait with watch.sh" "$scratch/evalpage.zero" && ! grep -q "page: open" "$scratch/evalpage.zero"'
check "EVAL_PAGE_DISPLAY=1 prints the page link" 'grep -q "page: open http://127.0.0.1:" "$scratch/evalpage.on"'
check "without EVAL_PAGE_DISPLAY the editor opens, not the page" 'grep -q "draft: wait with watch.sh" "$scratch/evalpage.off" && ! grep -q "page: open" "$scratch/evalpage.off"'
exit $fail
