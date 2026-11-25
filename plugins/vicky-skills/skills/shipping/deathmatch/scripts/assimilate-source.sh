#!/usr/bin/env bash
# assimilate-source.sh <comments json> <body edited at>: says which text a build
# on a pull request takes as its work list, the newer of the pull request body
# and its latest assimilate comment. Prints "comment <id>" when that comment is
# newer than the body's last edit, "body" when the body is newer or equal, and
# "none" when no comment is an assimilate comment. An assimilate comment starts
# with "Assimilate verdict for <sha>", or holds the headings "The four answers"
# and "The patch". The comments file is a JSON array of {id, body, created_at,
# updated_at}, the shape Gitea and GitHub both give. Exits 2 on a file or time
# it cannot read.
set -u
file=${1:-}; since=${2:-}
[ -r "$file" ] && [ -n "$since" ] || { echo "usage: assimilate-source.sh <comments json> <body edited at>" >&2; exit 2; }
want=$(date -d "$since" +%s 2>/dev/null) || { echo "assimilate-source.sh: no time in '$since'" >&2; exit 2; }
# jq reads only a Z time, and Gitea gives an offset, so date orders them.
list=$(jq -r '.[] | select((.body // "") | test("^Assimilate verdict for |(^|\\n)#+ *The four answers *\\n[\\s\\S]*\\n#+ *The patch *(\\n|$)"))
  | "\(.id) \(.updated_at // .created_at)"' "$file" 2>/dev/null) || { echo "assimilate-source.sh: $file is no comments list" >&2; exit 2; }
[ -n "$list" ] || { echo none; exit 0; }
id=; at=
while read -r i t; do
  s=$(date -d "$t" +%s 2>/dev/null) || { echo "assimilate-source.sh: comment $i has no time" >&2; exit 2; }
  [ -n "$at" ] && [ "$s" -le "$at" ] || { id=$i; at=$s; }
done <<<"$list"
if [ "$at" -gt "$want" ]; then echo "comment $id"; else echo body; fi
