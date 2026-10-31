#!/usr/bin/env bash
# page.py's decisions beyond the approved examples: comments, odd answers,
# a second Done, the timeout and bad arguments. Runs the page with a
# stand-in browser that records its address.
set -u
# No test may reach the user's own editor or browser.
export VISUAL=true EDITOR=true
page="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/skills/productivity/interactive-page/scripts/page.py"
scratch=$(mktemp -d)
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

python3 -I "$page" >/dev/null 2>&1; none=$?
python3 -I "$page" a b >/dev/null 2>&1; two=$?
check "no file, or two, is a usage error" '[ "$none" = 2 ] && [ "$two" = 2 ]'
exit $fail
