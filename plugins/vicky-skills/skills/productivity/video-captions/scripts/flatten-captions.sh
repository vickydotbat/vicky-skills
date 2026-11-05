#!/usr/bin/env bash
# Flattens a .vtt caption file to prose on stdout: drops the header, timings
# and inline tags, and keeps each repeated caption line once, since automatic
# captions repeat every line as the next one rolls in.
# Usage: flatten-captions.sh <file>.vtt > transcript.txt
set -u
file=${1:?usage: flatten-captions.sh <file>.vtt}
[ -r "$file" ] || { echo "flatten-captions: cannot read $file" >&2; exit 1; }
grep -vE '^(WEBVTT|Kind:|Language:|[0-9:.]+ --> |\s*$)' "$file" \
  | sed 's/<[^>]*>//g' \
  | awk '!seen[$0]++' \
  | tr '\n' ' ' \
  | sed 's/ *$//' \
  | fold -s -w 200
echo
