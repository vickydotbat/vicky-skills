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
# A run records only this session's own id, so pr-guard finds the record it looks for.
refuse_other() {
  if [ -n "${CLAUDE_CODE_SESSION_ID:-}" ] && [ "$1" != "$CLAUDE_CODE_SESSION_ID" ]; then
    echo "verdict.sh: $1 is not this session; this session is $CLAUDE_CODE_SESSION_ID. Run: verdict.sh $2 $CLAUDE_CODE_SESSION_ID" >&2; exit 2
  fi
}
# The body holds a verdict for exactly this sha, read as text: a prefix of another sha is not it.
holds() { grep -qE "Deathmatch verdict for $(printf %s "$1" | sed 's/[^0-9A-Za-z]/\\&/g')([^0-9a-fA-F]|$)" "$2" 2>/dev/null; }
if [ "${1:-}" = record ]; then
  [ -n "${2:-}" ] || { echo "usage: verdict.sh record <session id>" >&2; exit 2; }
  refuse_other "$2" record
  branch=$(git branch --show-current 2>/dev/null); dir="$(git rev-parse --git-common-dir 2>/dev/null)/vicky-skills/deathmatch"
  [ -n "$branch" ] || { echo "verdict.sh: not on a branch" >&2; exit 2; }
  mkdir -p "$(dirname "$dir/$branch")" && echo "$2 $(git rev-parse HEAD)" >>"$dir/$branch"
  exit 0
fi
if [ "${1:-}" = carry ]; then
  body=${2:-}; sha=${3:-}; from=${4:-}
  [ -n "$body" ] && [ -n "$sha" ] && [ -n "$from" ] || { echo "usage: verdict.sh carry <body file> <head sha> <verdict sha> [session id]" >&2; exit 2; }
  [ -z "${5:-}" ] || refuse_other "$5" "carry $body $sha $from"
  holds "$from" "$body" || { echo "verdict.sh: the body holds no verdict for $from" >&2; exit 1; }
  [ -n "$(tail -c1 "$body" 2>/dev/null)" ] && echo >>"$body"
  echo "Deathmatch verdict for $sha: carried from $from, assimilate patch only, $(date -u +%FT%TZ)" >>"$body"
  [ -z "${5:-}" ] || exec bash "$0" record "$5"
  exit 0
fi
[ "${1:-}" = due ] || { echo "usage: verdict.sh due <body file> <head sha> | record <session id> | carry <body file> <head sha> <verdict sha>" >&2; exit 2; }
body=${2:-}; sha=${3:-}
[ -n "$body" ] && [ -n "$sha" ] || { echo "usage: verdict.sh due <body file> <head sha>" >&2; exit 2; }
holds "$sha" "$body" && exit 1
exit 0 # mutant-ok delete: a no-op in its place also ends the script with status 0
