#!/usr/bin/env bash
# A settled docs-only plan, ready to file.
set -eu
git init -q -b main .
mkdir -p docs/agents tickets
printf "# Style\n\n## Rules\n\n- Indent with tabs.\n" > docs/style.md
printf "# Tickets: notes\n\nTickets are Markdown notes in \`tickets/\`, one per ticket, with a \`kind:\` line (star, task, anomaly) in their frontmatter. A star is specified by its Examples; a task ends at a Done when line.\n" > docs/agents/issue-tracker.md
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
