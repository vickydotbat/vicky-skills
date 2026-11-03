#!/usr/bin/env bash
# fetch-drawio.sh keeps an archive only when its SHA-256 matches the pin, and
# unpacks it once. A fixture archive, served from a file URL, stands in for
# the real release, so the test needs no network.
set -u
fetch="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/skills/productivity/drawing-board/scripts/fetch-drawio.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
python3 -I -c 'import sys, zipfile
with zipfile.ZipFile(sys.argv[1], "w") as z: z.writestr("index.html", "<title>draw.io</title>")' "$dir/app.war"
python3 -I -c 'import sys, zipfile
with zipfile.ZipFile(sys.argv[1], "w") as z: z.writestr("../escape.txt", "x")' "$dir/bad.war"
good=$(sha256sum "$dir/app.war" | cut -d' ' -f1)
bad=$(sha256sum "$dir/bad.war" | cut -d' ' -f1)
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
run() { CLAUDE_PLUGIN_DATA="$dir/data" DRAWIO_URL="file://$dir/$1" DRAWIO_SHA256="$2" bash "$fetch" 2>"$dir/err"; }
mkdir -p "$dir/data"
home=$(run app.war "$good")
check "a matching archive is unpacked and named" '[ -f "$home/index.html" ] && [ "$home" = "$dir/data/drawio/$good" ]'
check "a second run reuses it" '[ "$(run missing.war "$good")" = "$home" ]'
check "a wrong hash keeps nothing" '! run app.war 0000 >/dev/null && grep -q "not the pinned" "$dir/err" && [ ! -d "$dir/data/drawio/0000" ]'
check "an entry outside the folder is refused" '! run bad.war "$bad" >/dev/null && [ ! -f "$dir/data/escape.txt" ] && [ ! -d "$dir/data/drawio/$bad" ]'
check "no data folder, no fetch" '! CLAUDE_PLUGIN_DATA= bash "$fetch" >/dev/null 2>&1'
check "the fetch folder is cleaned up" '[ -z "$(ls -d "$dir/data"/drawio-fetch.* 2>/dev/null)" ]'
exit $fail
