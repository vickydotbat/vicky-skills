#!/usr/bin/env bash
# A branch whose only test passes when a doc holds a phrase.
set -eu
git init -q -b main .
mkdir -p docs/agents tickets
printf "# Style\n\n## Rules\n\n- Indent with tabs.\n" > docs/style.md
printf "# Tickets: notes\n\nTickets are Markdown notes in \`tickets/\`, one per ticket, with a \`kind:\` line (star, task, anomaly) in their frontmatter. A star is specified by its Examples; a task ends at a Done when line.\n" > docs/agents/issue-tracker.md
printf "# Agent rules\n\nWork on a branch.\n" > AGENTS.md
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
git switch -q -c two-space
printf "# Style\n\n## Rules\n\n- Indent with two spaces, never with tabs.\n" > docs/style.md
mkdir -p tests
printf '#!/usr/bin/env bash\n# The style rule is two spaces.\ngrep -q "two spaces" docs/style.md\n' > tests/style_rule.test.sh
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m "Two-space rule, with its test"
