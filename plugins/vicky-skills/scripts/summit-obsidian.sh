#!/usr/bin/env bash
# The Summit count for an Obsidian tracker: prints "<opened> <closed>" for the
# notes in <folder> since $SUMMIT_SINCE, by the rules of the tracker's "since"
# operations. A note is new when the timestamp its name starts with is at or
# after the time. It is closed when it says status: done and its closed: date is
# on or after the time's date, or it has no closed: date and changed since.
#   summit-obsidian.sh <folder>
set -u
dir=${1:?usage: summit-obsidian.sh <folder>}
since=${SUMMIT_SINCE:?SUMMIT_SINCE is not set}
[ -d "$dir" ] && [ "$dir" != / ] || { echo "summit-obsidian: no folder $dir" >&2; exit 1; }
from=$(date -d "$since" +%Y%m%d%H%M%S) && day=$(date -d "$since" +%F) || exit 1
opened=0 closed=0
for f in "$dir"/*.md; do
  [ -f "$f" ] || continue
  name=${f##*/}
  [[ "$name" =~ ^([0-9]{14}) ]] && [ "$((10#${BASH_REMATCH[1]}))" -ge "$((10#$from))" ] && opened=$((opened + 1))
  grep -q '^status: done' "$f" || continue
  when=$(sed -n 's/^closed:[[:space:]]*\([0-9-]*\).*/\1/p' "$f" | head -1)
  if [ -n "$when" ]; then [ "$when" \< "$day" ] || closed=$((closed + 1))
  elif [ -n "$(find "$f" -newermt "$since")" ]; then closed=$((closed + 1)); fi
done
echo "$opened $closed"
