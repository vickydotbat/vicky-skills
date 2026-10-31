#!/usr/bin/env bash
# The ledger of engraved lessons, lessons.tsv in the plugin's data folder:
# one line per lesson, the UTC time, its home (plugin, setup or repo) and its
# snag, tab-separated. engrave adds a line wherever the lesson went, so sup
# counts lessons from every repo, not only the commits of the one it runs in.
# Usage: lesson-ledger.sh add <home> <snag>
#        lesson-ledger.sh since <UTC time, such as 2026-10-31T12:00:00Z>
set -u
[ -n "${CLAUDE_PLUGIN_DATA:-}" ] || { echo "lesson-ledger: CLAUDE_PLUGIN_DATA is not set" >&2; exit 2; }
file="$CLAUDE_PLUGIN_DATA/lessons.tsv"
case "${1:-}" in
  add)
    [ $# = 3 ] || { echo "usage: lesson-ledger.sh add <home> <snag>" >&2; exit 2; }
    mkdir -p "$CLAUDE_PLUGIN_DATA"
    # A tab or a newline in the snag would break the ledger's columns.
    printf '%s\t%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$2" "$(tr '\t\n' '  ' <<<"$3" | sed 's/ *$//')" >> "$file"
    ;;
  since)
    [ $# = 2 ] || { echo "usage: lesson-ledger.sh since <UTC time>" >&2; exit 2; }
    # ISO times in UTC sort as text, so a string comparison is a time comparison.
    awk -F '\t' -v t="$2" '$1 >= t {print $3 " (" $2 ")"}' "$file" 2>/dev/null
    ;;
  *) echo "usage: lesson-ledger.sh add <home> <snag> | since <UTC time>" >&2; exit 2 ;;
esac
exit 0 # mutant-ok delete: each branch above ends on a command that exits 0 or exits itself
