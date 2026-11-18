#!/usr/bin/env bash
# Fetches the draw.io web app once, pinned to one release and checked by its
# SHA-256, and prints the folder that holds it, for page.py's DRAWIO_HOME.
# The archive is unpacked into a folder of its own and only ever served as
# files: nothing in it runs here.
# DRAWIO_URL and DRAWIO_SHA256 replace the pin, for a test's fixture archive.
set -eu
version=32.6.9 # mutant-ok delete: only the default URL reads it, and a test fetches its fixture, never the release
url=${DRAWIO_URL:-https://github.com/jgraph/drawio/releases/download/v$version/draw.war}
sum=${DRAWIO_SHA256:-31afc82b7920c409d0591f6126ccb6c377d7800e7f11ab324f88bdf1e4249ce7}
data=${CLAUDE_PLUGIN_DATA:?fetch-drawio: CLAUDE_PLUGIN_DATA is not set}
home="$data/drawio/$sum"
[ -f "$home/index.html" ] && { echo "$home"; exit 0; }
tmp=$(mktemp -d "$data/drawio-fetch.XXXXXX")
trap 'rm -rf -- "$tmp"' EXIT
curl -fsSL --retry 2 -o "$tmp/draw.war" "$url" || { echo "fetch-drawio: could not download $url" >&2; exit 1; }
got=$(sha256sum "$tmp/draw.war" | cut -d' ' -f1)
[ "$got" = "$sum" ] || { echo "fetch-drawio: $url has SHA-256 $got, not the pinned $sum; nothing kept" >&2; exit 1; }
# Python's zipfile unpacks: it drops "..", absolute paths and drive letters
# from entry names, so nothing lands outside the folder.
python3 -I -c 'import sys, zipfile; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])' "$tmp/draw.war" "$tmp/app"
[ -f "$tmp/app/index.html" ] || { echo "fetch-drawio: the archive holds no index.html" >&2; exit 1; }
mkdir -p "$data/drawio"
mv "$tmp/app" "$home"
echo "$home"
