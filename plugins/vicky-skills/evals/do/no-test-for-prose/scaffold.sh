#!/usr/bin/env bash
# A docs-only task in a trunk repo with a test suite.
set -eu
git init -q -b main .
mkdir -p docs/agents tickets
printf "# Style\n\n## Rules\n\n- Indent with tabs.\n" > docs/style.md
printf "# Tickets: notes\n\nTickets are Markdown notes in \`tickets/\`, one per ticket, with a \`kind:\` line (star, task, anomaly) in their frontmatter. A star is specified by its Examples; a task ends at a Done when line.\n" > docs/agents/issue-tracker.md
mkdir -p tests
printf '#!/usr/bin/env bash\nfor t in tests/*.test.sh; do bash "$t" || exit 1; done\n' > tests/run-all.sh
printf "# Agent rules\n\nTrunk: commit straight to main. Tests live in tests/ and run with tests/run-all.sh.\n" > AGENTS.md
printf -- "---\nkind: task\n---\n# Two-space indent rule\n\nDone when docs/style.md's rules say: indent with two spaces, and never with tabs.\n\n## Comments\n" > tickets/5-style-rules.md
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
