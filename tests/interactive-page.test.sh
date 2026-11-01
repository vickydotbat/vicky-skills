#!/usr/bin/env bash
# page.py's decisions beyond the approved examples: comments, odd answers,
# a second Done, the timeout and bad arguments. Runs the page with a
# stand-in browser that records its address.
set -u
# No test may reach the user's own editor or browser.
export VISUAL=true EDITOR=true BROWSER=true
page="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/skills/productivity/interactive-page/scripts/page.py"
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
  BROWSER="$scratch/browser" python3 -I "$page" "$1" --timeout "${2:-30}" 2>/dev/null &
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
{ printf 'text.0='; head -c 1100000 /dev/zero | tr '\0' 'x'; } >"$scratch/huge"
big=$(curl -s -o /dev/null -w '%{http_code}' -X POST --data-binary "@$scratch/huge" "${url%/}/done")
check "an answer over 1 MB is refused" '[ "$big" = 400 ] && ! grep -q xxxxxxxx "$scratch/d.md"'
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
check "approve all shows on a page with two approve boxes, and not on a page with one" \
  'grep -q "name=\"approve_all\"" <<<"$two_box" && ! grep -q "approve_all" <<<"$one_box"'

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

python3 -I "$page" >/dev/null 2>&1; none=$?
python3 -I "$page" a b >/dev/null 2>&1; two=$?
check "no file, or two, is a usage error" '[ "$none" = 2 ] && [ "$two" = 2 ]'
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
check "signed off and proven by fold into one collapsed header" '[ "$(grep -c "<summary>Signed off and proven by" <<<"$html")" = 1 ] && grep -q "<code>health.sh</code>" <<<"$html"'
check "quick notes fold into a block that opens when a note is filled" 'grep -q "<details class=quick open><summary>Quick notes" <<<"$html" && grep -q "IDEA: <input type=text name=\"field.2\" value=\"later\">" <<<"$html"'
blank=$(sed 's/^- IDEA: later$/- IDEA:/' "$scratch/cards.md" | render)
check "a quick-notes block with no note stays closed" 'grep -q "<details class=quick><summary>" <<<"$blank"'
check "a no-op Done writes the checklist back byte for byte" 'python3 -I -c "import sys; sys.path.insert(0, sys.argv[1]); import page; t=open(sys.argv[2]).read(); sys.exit(page.answered(page.parse(t, \"/\"), {}) != t)" "$(dirname "$page")" "$scratch/cards.md"'
exit $fail
