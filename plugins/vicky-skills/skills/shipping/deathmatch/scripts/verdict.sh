#!/usr/bin/env bash
# verdict.sh due <pull request body file> <head sha>: exits 0 when the head
# commit still needs a deathmatch, and 1 when the body already holds its
# verdict line ("Deathmatch verdict for <sha>"), so make-it-so runs it once
# per head commit.
# verdict.sh record <session id>: records that deathmatch ran on the current
# branch in this session, at <git common dir>/vicky-skills/deathmatch/<branch>.
# pr-guard reads it before a pull request goes ready.
set -u
if [ "${1:-}" = record ]; then
  [ -n "${2:-}" ] || { echo "usage: verdict.sh record <session id>" >&2; exit 2; }
  branch=$(git branch --show-current 2>/dev/null); dir="$(git rev-parse --git-common-dir 2>/dev/null)/vicky-skills/deathmatch"
  [ -n "$branch" ] || { echo "verdict.sh: not on a branch" >&2; exit 2; }
  mkdir -p "$(dirname "$dir/$branch")" && echo "$2" >>"$dir/$branch"
  exit 0
fi
[ "${1:-}" = due ] || { echo "usage: verdict.sh due <body file> <head sha> | record <session id>" >&2; exit 2; }
body=${2:-}; sha=${3:-}
[ -n "$body" ] && [ -n "$sha" ] || { echo "usage: verdict.sh due <body file> <head sha>" >&2; exit 2; }
grep -q "Deathmatch verdict for $sha" "$body" 2>/dev/null && exit 1
exit 0 # mutant-ok delete: a no-op in its place also ends the script with status 0
