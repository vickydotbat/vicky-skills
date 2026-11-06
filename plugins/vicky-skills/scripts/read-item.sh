#!/usr/bin/env bash
# Reads one tracker item whole, body and comments, the way the repo's
# docs/agents/issue-tracker.md says: its "Read, whole" row. A row holding a
# command in backticks runs it, with the id in place of <n>, <id> or <key>. A
# row with no command is an instruction, printed with the id for the agent to
# follow. So every tracker reads the same way, and no hook has to know them.
set -u
id=${1:?usage: read-item.sh <id>}
doc="$(git rev-parse --show-toplevel 2>/dev/null || pwd)/docs/agents/issue-tracker.md"
[ -f "$doc" ] || { echo "read-item: no docs/agents/issue-tracker.md here; run first-contact to write one." >&2; exit 2; } # mutant-ok delete: grep on a missing file fails too, and the row check below exits 2 the same way
row=$(grep -m1 -E '^\|[[:space:]]*Read, whole' "$doc") || { echo "read-item: $doc has no 'Read, whole' row." >&2; exit 2; }
how=$(sed -E 's/^\|[^|]*\|[[:space:]]*//; s/[[:space:]]*\|[[:space:]]*$//' <<<"$row")
if [[ $how =~ ^\`([^\`]+)\`$ ]]; then
  cmd=${BASH_REMATCH[1]}
  q=$(printf %q "$id")
  cmd=${cmd//<n>/$q}; cmd=${cmd//<id>/$q}; cmd=${cmd//<key>/$q}
  exec bash -c "$cmd"
fi
printf 'Read %s whole: %s\n' "$id" "${how:-the steps under its Read, whole heading in $doc}"
