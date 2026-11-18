#!/usr/bin/env bash
# A settled plan with a plain risk: stored favourites hold row numbers.
set -eu
git init -q -b main .
mkdir -p docs/agents tickets data
printf "id,label\n1,Wolf\n2,Bear\n" > data/creatures.csv
printf "# Favourites\n\nA DM's favourites are stored as creature row numbers.\n" > docs/favourites.md
printf "# Tickets: notes\n\nTickets are Markdown notes in \`tickets/\`, one per ticket, with a \`kind:\` line (chart, star, task, anomaly) in their frontmatter. A star chart is a note with \`kind: chart\`; its tickets name it on a \`parent:\` line. A star is specified by its Examples; a task ends at a Done when line.\n" > docs/agents/issue-tracker.md
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
