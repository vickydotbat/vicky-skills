#!/usr/bin/env bash
# approved-spec: the approve-all example, approved 2026-11-07 on a drafts page.
# The check opens a drafts page through open-page.sh with a stand-in browser
# that records the page's address, then reads the page the way a browser does.
set -u
export VISUAL=true EDITOR=true BROWSER=true
root="$(cd "$(dirname "$0")/.." && pwd)"
open_page="$root/plugins/vicky-skills/skills/productivity/interactive-page/scripts/open-page.sh"
scratch=$(mktemp -d)
mkdir -p "$scratch/desktop"
printf '#!/usr/bin/env bash\necho "PATH=$PATH"\necho "BROWSER=${BROWSER:-true}"\n' >"$scratch/desktop/systemctl"
chmod +x "$scratch/desktop/systemctl"
export PATH="$scratch/desktop:$PATH"
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


# AA1
# Given a drafts page with one approve box
# When the page opens
# Then an approve all box sits beside Done
printf '## One\nsrc/a.txt:1\n- [ ] approve\n\n```text\nOne\n```\n' >"$scratch/one.md"
start "$scratch/one.md"
html=$(curl -s "$url"); kill "$pid" 2>/dev/null
check "AA1 a page with one approve box shows approve all" 'grep -q "name=\"approve_all\"" <<<"$html"'
exit $fail
