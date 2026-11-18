#!/usr/bin/env bash
# Lists the notes in an Obsidian tracker folder that every tracker operation
# misses: a note with no `status:` line in its frontmatter, a status outside
# open, claimed, waiting and done, or a name without its YYYYMMDDHHMMSS
# timestamp. The "since" counts read the status and the name, so a note
# listed here skews summit's opened and closed numbers. It reads subfolders
# too, as the "since" operations' find does.
# Usage: tracker-status.sh <tracker folder>
# Prints one line per note and exits 1, or prints a pass line and exits 0.
set -u
[ $# = 1 ] || { echo "usage: tracker-status.sh <tracker folder>" >&2; exit 2; }
dir=${1%/}
[ -d "$dir" ] || { echo "tracker-status: no folder $dir" >&2; exit 2; }
n=0 bad=0
while IFS= read -r -d '' f; do
  n=$((n + 1)); name=${f#"$dir"/}
  # The status counts only inside the frontmatter: the block between a first
  # line of --- and the next ---.
  status=$(awk 'NR == 1 && $0 != "---" {exit} NR > 1 && $0 == "---" {exit} NR > 1 && sub(/^status:[ \t]*/, "") {print; exit}' "$f")
  # The four statuses of the tracker operations' "Move a ticket to <state>".
  case "$status" in
    open|claimed|waiting|done) ;;
    "") echo "no status: $name"; bad=1 ;;
    *) echo "bad status \"$status\": $name"; bad=1 ;;
  esac
  [[ "${name##*/}" =~ ^[0-9]{14}\  ]] || { echo "no timestamp: $name"; bad=1; }
done < <(find "$dir" -name '*.md' -type f -print0 | sort -z)
[ $bad = 0 ] || exit 1
echo "tracker-status: $n notes, all on the tracker"
