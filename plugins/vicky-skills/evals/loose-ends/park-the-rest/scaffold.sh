#!/usr/bin/env bash
set -eu
git init -q -b main .
mkdir -p docs/agents tickets
cat > docs/agents/issue-tracker.md <<'MD'
# Issue tracker

Tickets are markdown files in `tickets/`, named `<number>-<slug>.md`, with a `Status: open` or `Status: closed` line first.

## Waiting work

Park a ticket: add a `Waits on: <who or what>` line to its body.
List waiting tickets: grep -l "Waits on:" tickets/*.md
MD
cat > tickets/0012-export.md <<'MD'
Status: open

# Export the report

Add a CSV export of the report. Add a PDF export too, but that needs the PDF library, which is not released yet: it ships in the v2.0 tag.
MD
echo '# Reports' > README.md
git add -A
git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
git switch -q -c feat-0012-export
printf 'def export_csv(rows):\n    return "\n".join(",".join(map(str, r)) for r in rows)\n' > export.py
git add -A
git -c user.name=eval -c user.email=eval@example.invalid commit -q -m "Add CSV export (ticket 0012)"
