#!/usr/bin/env bash
# approved-spec: the examples the user set for the interactive-page skill on
# 2026-10-31. Each check opens a draft file or a checklist the way red-pen and
# over-to-you do, through open-page.sh, with a stand-in browser that records
# the page's address, then answers the page the way the browser's form does.
set -u
# No test may reach the user's own editor or browser.
export VISUAL=true EDITOR=true
root="$(cd "$(dirname "$0")/.." && pwd)"
open_page="$root/plugins/vicky-skills/skills/productivity/interactive-page/scripts/open-page.sh"
draft_lock="$root/plugins/vicky-skills/scripts/draft-lock.sh"
scratch=$(mktemp -d)
pids=()
cleanup() { for p in "${pids[@]}"; do kill "$p" 2>/dev/null; done; rm -rf "$scratch"; }
trap cleanup EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

repo="$scratch/repo"
git init -q "$repo"
mkdir -p "$repo/src"
echo 'Hello there' >"$repo/src/greet.txt"
gitdir="$repo/.git"

cat >"$scratch/drafts.template" <<'EOF'
# Drafts: test

Press Done to send these back.

## Greeting
src/greet.txt:1
- [ ] approve

```text
Hello there
```

## Charm example
tests/charm_approved_examples.test.sh:new
- [ ] approve

```text
Given a creature charmed by another
```
EOF

cat >"$scratch/checklist.template" <<'EOF'
# Over to you, Vicky!

Mark each item.

## Inventory

1. [ ] Open the pack → the slots show
   notes:

2. [ ] Drop a coin → it lands
   notes:

quick notes:
- BUG:
EOF

# A browser that records the address it was asked to open.
printf '#!/usr/bin/env bash\necho "$1" >"%s/url"\n' "$scratch" >"$scratch/browser"
# An editor that records the file it was asked to open, then closes.
printf '#!/usr/bin/env bash\necho "$1" >"%s/edited"\n' "$scratch" >"$scratch/editor"
chmod +x "$scratch/browser" "$scratch/editor"

# Opens $1 (a copy of a template) in the background; sets pid and url.
start() {
  rm -f "$scratch/url"
  (cd "$repo" && DISPLAY=:99 BROWSER="$scratch/browser" bash "$open_page" "$1" >"$scratch/open.log" 2>&1) &
  pid=$!
  pids+=("$pid")
  for _ in $(seq 50); do [ -s "$scratch/url" ] && break; sleep 0.2; done
  url=$(cat "$scratch/url" 2>/dev/null)
}
page() { curl -s "$url"; }
# Presses Done with the form fields given as name=value pairs.
done_with() {
  local args=()
  for pair in "$@"; do args+=(--data-urlencode "$pair"); done
  curl -s -o /dev/null -X POST "${args[@]}" "${url%/}/done"
  for _ in $(seq 50); do kill -0 "$pid" 2>/dev/null || break; sleep 0.2; done
}
gone() { ! kill -0 "$pid" 2>/dev/null; }
untouched=(text.0="Hello there" text.1="Given a creature charmed by another" comment.0= comment.1=)

cp "$scratch/drafts.template" "$scratch/d1.md"
start "$scratch/d1.md"
html=$(page)
check "drafts open as one page in my browser, each draft with editable text, a comment box and an approve box" \
  '[ -n "$url" ] && grep -q "name=\"text.0\"" <<<"$html" && grep -q "name=\"text.1\"" <<<"$html" && grep -q "name=\"comment.0\"" <<<"$html" && grep -q "name=\"comment.1\"" <<<"$html" && grep -q "type=checkbox name=\"approve.0\"" <<<"$html" && grep -q "type=checkbox name=\"approve.1\"" <<<"$html"'
done_with text.0="Well met, traveller" text.1="Given a creature charmed by another" comment.0= comment.1=
check "when I edit a draft's text and press Done, my text comes back word for word" \
  'gone && grep -qx "Well met, traveller" "$scratch/d1.md" && ! grep -qx "Hello there" "$scratch/d1.md"'

rm -f "$gitdir/approved-spec-grants"
cp "$scratch/drafts.template" "$scratch/d2.md"
start "$scratch/d2.md"
done_with "${untouched[@]}"
check "Done with nothing changed takes every draft as it stands, and grants nothing" \
  '[ -n "$url" ] && gone && cmp -s "$scratch/drafts.template" "$scratch/d2.md" && [ ! -s "$gitdir/approved-spec-grants" ]'

rm -f "$gitdir/approved-spec-grants"
cp "$scratch/drafts.template" "$scratch/d3.md"
start "$scratch/d3.md"
done_with "${untouched[@]}" approve.1=on
check "ticking one approved test's box opens that test file for edits, and no other" \
  'gone && grep -qx "tests/charm_approved_examples.test.sh" "$gitdir/approved-spec-grants" && ! grep -q "src/greet.txt" "$gitdir/approved-spec-grants"'

lock_says() {
  jq -nc --arg f "$repo/src/greet.txt" --arg d "$repo" '{tool_name: "Edit", cwd: $d, tool_input: {file_path: $f}}' |
    CLAUDE_PLUGIN_OPTION_GUARD_DRAFT_LOCK=true bash "$draft_lock" >/dev/null 2>&1
  echo $?
}
cp "$scratch/drafts.template" "$scratch/d4.md"
start "$scratch/d4.md"
while_open=$(lock_says)
done_with "${untouched[@]}"
after=$(lock_says)
check "while the drafts page is open, an edit to the repo's code is refused until I press Done" \
  '[ "$while_open" = 2 ] && [ "$after" = 0 ]'

cp "$scratch/checklist.template" "$scratch/c1.md"
start "$scratch/c1.md"
html=$(page)
sleep 1
waiting=no; kill -0 "$pid" 2>/dev/null && waiting=yes
done_with mark.0=x mark.1=" " field.0="slots look right" field.1= field.2=
check "a checklist opens as the same kind of page, a box per check and a notes box, and the agent waits until I finish" \
  '[ "$waiting" = yes ] && grep -q "name=\"mark.0\"" <<<"$html" && grep -q "name=\"mark.1\"" <<<"$html" && grep -q "name=\"field.0\"" <<<"$html" && gone && grep -q "^1\. \[x\] Open the pack" "$scratch/c1.md" && grep -q "^   notes: slots look right$" "$scratch/c1.md" && grep -q "^2\. \[ \] Drop a coin" "$scratch/c1.md"'

cp "$scratch/drafts.template" "$scratch/d5.md"
rm -f "$scratch/edited"
(cd "$repo" && env -u DISPLAY -u WAYLAND_DISPLAY VISUAL="$scratch/editor" timeout 20 bash "$open_page" "$scratch/d5.md" >/dev/null 2>&1)
status=$?
check "with no browser on the machine, the drafts open in my editor instead, and the agent waits for the close" \
  '[ "$status" = 0 ] && [ "$(cat "$scratch/edited" 2>/dev/null)" = "$scratch/d5.md" ]'

red_pen="$root/plugins/vicky-skills/skills/productivity/red-pen/SKILL.md"
cp "$scratch/drafts.template" "$scratch/d6.md"
start "$scratch/d6.md"
done_with text.0="Hello there" text.1="Given a creature charmed by another" comment.0="Warmer, please" comment.1=
check "a comment I type under a draft reaches the agent, which acts on my note before it writes the draft's text back" \
  'gone && [ "$(grep -A2 -x "Hello there" "$scratch/d6.md" | tail -1)" = "Comment: Warmer, please" ] && sed -n "/^3\. \*\*Write back/,/^4\. /p" "$red_pen" | grep -q "act on it before you write the block back"'

cat >"$scratch/question.md" <<'EOF'
# A question for you

## Q1: Which colour for the band border?
- ( ) gray
- (x) the phase colour
EOF
interactive="$root/plugins/vicky-skills/skills/productivity/interactive-page/SKILL.md"
start "$scratch/question.md"
html=$(page)
done_with choice.0=gray
check "an agent's question with options is answered on a page by clicking, not in chat" \
  'grep -q "type=radio name=\"choice.0\" value=\"gray\"" <<<"$html" && gone && grep -qx -- "- (x) gray" "$scratch/question.md" && grep -qx -- "- ( ) the phase colour" "$scratch/question.md" && grep -qi "question" "$interactive"'
exit $fail
