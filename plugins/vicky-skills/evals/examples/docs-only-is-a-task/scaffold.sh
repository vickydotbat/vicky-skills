#!/usr/bin/env bash
# A docs-only ticket: its whole change is rewriting the rules in a doc.
set -eu
git init -q -b main .
mkdir -p docs/agents tickets
printf "# Style\n\n## Rules\n\n- Indent with tabs.\n" > docs/style.md
printf "# Tickets: notes\n\nTickets are Markdown notes in \`tickets/\`, one per ticket, with a \`kind:\` line (star, task, anomaly) in their frontmatter. A star is specified by its Examples; a task ends at a Done when line.\n" > docs/agents/issue-tracker.md
printf -- "---\nkind: star\n---\n# Two-space indent rule\n\nRewrite the rules in docs/style.md so they say: indent with two spaces, and never with tabs.\n\n## Comments\n" > tickets/4-style-rules.md
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
