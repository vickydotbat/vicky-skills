#!/usr/bin/env bash
# approved-spec: the examples the user set on 2026-10-31 for the star
# "interactive-page owns every page it opens". Each check opens a planning
# page the way warp and the council do, through open-page.sh, with a stand-in
# browser that records the page's address, then answers it the way the
# browser's form does.
set -u
# No test may reach the user's own editor or browser.
export VISUAL=true EDITOR=true
root="$(cd "$(dirname "$0")/.." && pwd)"
skills="$root/plugins/vicky-skills/skills"
open_page="$skills/productivity/interactive-page/scripts/open-page.sh"
open_draft="$skills/productivity/interactive-page/scripts/open-draft.sh"
page_py="$skills/productivity/interactive-page/scripts/page.py"
scratch=$(mktemp -d)
pids=()
cleanup() { for p in "${pids[@]}"; do kill "$p" 2>/dev/null; done; rm -rf "$scratch"; }
trap cleanup EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

repo="$scratch/repo"
git init -q "$repo"

printf '#!/usr/bin/env bash\necho "$1" >"%s/url"\n' "$scratch" >"$scratch/browser"
chmod +x "$scratch/browser"
start() {
  rm -f "$scratch/url"
  (cd "$repo" && DISPLAY=:99 BROWSER="$scratch/browser" bash "$open_page" "$1" >"$scratch/open.log" 2>&1) &
  pid=$!
  pids+=("$pid")
  for _ in $(seq 50); do [ -s "$scratch/url" ] && break; sleep 0.2; done
  url=$(cat "$scratch/url" 2>/dev/null)
}
done_with() {
  local args=()
  for pair in "$@"; do args+=(--data-urlencode "$pair"); done
  curl -s -o /dev/null -X POST "${args[@]}" "${url%/}/done"
  for _ in $(seq 50); do kill -0 "$pid" 2>/dev/null || break; sleep 0.2; done
}
gone() { ! kill -0 "$pid" 2>/dev/null; }

mkdir -p "$scratch/plan"
echo '<svg width="3000" height="100" xmlns="http://www.w3.org/2000/svg"><rect width="3000" height="100"/></svg>' >"$scratch/plan/chart.svg"
printf '# Pre-flight\n\n## Chart\n![Todo list warp](chart.svg)\n\n## Q1: Which?\n- (x) One\n- ( ) Two\n' >"$scratch/plan/chart.md"
start "$scratch/plan/chart.md"
html=$(curl -s "$url"); kill "$pid" 2>/dev/null
check "a chart on a page: the chart shows at its natural size, a chart wider than the window shrinks to fit, and a click on it zooms in" \
  'grep -qF "<div class=chart onclick=\"zoom(this)\"><svg width=\"3000\"" <<<"$html" && grep -qF ".chart svg{max-width:100%;height:auto" <<<"$html" && grep -qF "function zoom(c)" <<<"$html" && grep -qF "c.clientWidth*n" <<<"$html"'

printf '# Pre-flight\n\n![Todo list warp](missing.svg)\n\n## Q1: Which?\n- (x) One\n- ( ) Two\n' >"$scratch/plan/missing.md"
start "$scratch/plan/missing.md"
html=$(curl -s "$url")
done_with choice.0=Two
check "a chart that isn't there: I see that line as written, and the rest of the page works" \
  'grep -qF "![Todo list warp](missing.svg)" <<<"$html" && ! grep -q "<svg" <<<"$html" && gone && grep -qx -- "- (x) Two" "$scratch/plan/missing.md"'

cat >"$scratch/plan/course.md" <<'EOF'
# Pre-flight: Todo list warp

## Course
- [x] K-1 away team: Read docs. Needs: nothing
- [x] K-2 anomaly: Pick one. Needs: your answer
- [x] K-3 star: Build A. Needs: your approval of its examples
- [x] K-4 star: Build B. Needs: nothing
EOF
start "$scratch/plan/course.md"
html=$(curl -s "$url")
check "the course on a warp's pre-flight page: each ticket shows with its kind and what it needs from me, and its box is ticked to keep it" \
  '[ "$(grep -c "type=checkbox name=\"box\.[0-3]\" checked> K-[1-4] " <<<"$html")" = 4 ] && grep -qF "K-2 anomaly: Pick one. Needs: your answer" <<<"$html"'

done_with box.0=on box.1=on box.3=on
check "trimming the course: when I untick one ticket and press Done, the agent drops that ticket and keeps the other three" \
  'gone && grep -qx -- "- \[ \] K-3 star: Build A. Needs: your approval of its examples" "$scratch/plan/course.md" && [ "$(grep -c "^- \[x\] K-[124] " "$scratch/plan/course.md")" = 3 ] && grep -qi "unticked .*dropped from the course" "$skills/engineering/lay-course/STAR-CHART.md"'

printf '# A question for you\n\n## Q1: Which?\n- (x) One\n- ( ) Two\n' >"$scratch/q.md"
cp "$scratch/q.md" "$scratch/q.before"
(cd "$repo" && VISUAL="python3 -I $page_py --timeout 1" BROWSER="$scratch/browser" DISPLAY=:99 timeout 20 bash "$open_draft" "$scratch/q.md" >"$scratch/q.log" 2>&1)
status=$?
check "a page nobody answers: the page stops, the file stays as it was, and the agent asks me the same questions in chat instead of taking its pick" \
  '[ "$status" = 2 ] && grep -qF "no answer within" "$scratch/q.log" && cmp -s "$scratch/q.md" "$scratch/q.before" && grep -qi "ask the same questions in chat" "$skills/productivity/interactive-page/SKILL.md"'

check "one skill opens every page: it opens through interactive-page, and red-pen and lay-course have no page scripts of their own" \
  '[ -f "$open_draft" ] && [ ! -e "$skills/productivity/red-pen/scripts" ] && [ ! -e "$skills/engineering/lay-course/scripts/answer-page.py" ] && ! grep -rq "answer-page\|red-pen/scripts" "$root/plugins" && grep -q "open-page.sh" "$skills/engineering/lay-course/STAR-CHART.md"'

three='# Drafts: three

## One
src/a.txt:1
- [ ] approve

```text
One
```

## Two
src/b.txt:1
- [ ] approve

```text
Two
```

## Three
src/c.txt:1
- [ ] approve

```text
Three
```
'
untouched=(text.0=One text.1=Two text.2=Three comment.0= comment.1= comment.2=)
printf '%s' "$three" >"$scratch/all.md"
start "$scratch/all.md"
html=$(curl -s "$url")
done_with "${untouched[@]}" approve_all=on
check "approve all: when I tick approve all beside Done and press Done, every draft comes back approved, as if I had ticked each box" \
  'grep -q "name=\"approve_all\"" <<<"$html" && gone && [ "$(grep -c "^- \[x\] approve$" "$scratch/all.md")" = 3 ]'

printf '%s' "$three" >"$scratch/one.md"
start "$scratch/one.md"
done_with "${untouched[@]}" approve.1=on
check "approve all, left alone: only the box I ticked comes back approved" \
  'gone && [ "$(grep -c "^- \[x\] approve$" "$scratch/one.md")" = 1 ] && [ "$(grep -A1 -x "src/b.txt:1" "$scratch/one.md" | tail -1)" = "- [x] approve" ]'
exit $fail
