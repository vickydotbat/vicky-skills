#!/usr/bin/env bash
# verdict.sh due <pull request body file> <head sha>: exits 0 when the head
# commit still needs a deathmatch, and 1 when the body already holds its
# verdict line ("Deathmatch verdict for <sha>"), so make-it-so runs it once
# per head commit.
# verdict.sh record <session id>: records that deathmatch ran on the current
# branch's head commit in this session, as "<session id> <head sha>", at
# <git common dir>/vicky-skills/deathmatch/<branch>.
# pr-guard reads it before a pull request goes ready.
# verdict.sh carry <body file> <head sha> <verdict sha> [session id]: for a head
# commit that only applies an assimilate comment's own patch. Needs the body to
# hold "Deathmatch verdict for <verdict sha>", then writes "Deathmatch verdict
# for <head sha>: carried from <verdict sha>, assimilate patch only, <UTC time>"
# into it, so
# due exits 1 for the head commit. With a session id it also records the run.
set -u
if [ "${1:-}" = record ]; then
  [ -n "${2:-}" ] || { echo "usage: verdict.sh record <session id>" >&2; exit 2; }
  if [ -n "${CLAUDE_CODE_SESSION_ID:-}" ] && [ "$2" != "$CLAUDE_CODE_SESSION_ID" ]; then
    echo "verdict.sh: $2 is not this session; this session is $CLAUDE_CODE_SESSION_ID. Run: verdict.sh record $CLAUDE_CODE_SESSION_ID" >&2; exit 2
  fi
  branch=$(git branch --show-current 2>/dev/null); dir="$(git rev-parse --git-common-dir 2>/dev/null)/vicky-skills/deathmatch"
  [ -n "$branch" ] || { echo "verdict.sh: not on a branch" >&2; exit 2; }
  mkdir -p "$(dirname "$dir/$branch")" && echo "$2 $(git rev-parse HEAD)" >>"$dir/$branch"
  exit 0
fi
if [ "${1:-}" = carry ]; then
  body=${2:-}; sha=${3:-}; from=${4:-}
  [ -n "$body" ] && [ -n "$sha" ] && [ -n "$from" ] || { echo "usage: verdict.sh carry <body file> <head sha> <verdict sha> [session id]" >&2; exit 2; }
  grep -q "Deathmatch verdict for $from" "$body" 2>/dev/null || { echo "verdict.sh: the body holds no verdict for $from" >&2; exit 1; }
  echo "Deathmatch verdict for $sha: carried from $from, assimilate patch only, $(date -u +%FT%TZ)" >>"$body"
  [ -n "${5:-}" ] && bash "$0" record "$5"
  exit 0
fi
[ "${1:-}" = due ] || { echo "usage: verdict.sh due <body file> <head sha> | record <session id> | carry <body file> <head sha> <verdict sha>" >&2; exit 2; }
body=${2:-}; sha=${3:-}
[ -n "$body" ] && [ -n "$sha" ] || { echo "usage: verdict.sh due <body file> <head sha>" >&2; exit 2; }
grep -q "Deathmatch verdict for $sha" "$body" 2>/dev/null && exit 1
exit 0 # mutant-ok delete: a no-op in its place also ends the script with status 0
