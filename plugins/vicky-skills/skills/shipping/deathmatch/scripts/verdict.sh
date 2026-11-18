#!/usr/bin/env bash
# verdict.sh due <pull request body file> <head sha>: exits 0 when the head
# commit still needs a deathmatch, and 1 when the body already holds its
# verdict line ("Deathmatch verdict for <sha>"), so make-it-so runs it once
# per head commit.
set -u
[ "${1:-}" = due ] || { echo "usage: verdict.sh due <body file> <head sha>" >&2; exit 2; }
body=${2:?}; sha=${3:?}
grep -q "Deathmatch verdict for $sha" "$body" 2>/dev/null && exit 1
exit 0 # mutant-ok delete: a no-op in its place also ends the script with status 0
