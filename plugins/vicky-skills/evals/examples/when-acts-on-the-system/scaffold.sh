#!/usr/bin/env bash
# A behaviour ticket that also updates the command's doc.
set -eu
git init -q -b main .
mkdir -p docs/agents tickets
printf "# Style\n\n## Rules\n\n- Indent with tabs.\n" > docs/style.md
printf "# Tickets: notes\n\nTickets are Markdown notes in \`tickets/\`, one per ticket, with a \`kind:\` line (star, task, anomaly) in their frontmatter. A star is specified by its Examples; a task ends at a Done when line.\n" > docs/agents/issue-tracker.md
mkdir -p bin
printf '#!/usr/bin/env bash\necho Hello\n' > bin/greet.sh; chmod +x bin/greet.sh
printf "# greet\n\nRun bin/greet.sh to print Hello.\n" > docs/greet.md
printf -- "---\nkind: star\n---\n# greet takes a name\n\nbin/greet.sh takes a name and prints Hello, <name>. With no name it prints Hello, as today. Update docs/greet.md to match.\n\n## Comments\n" > tickets/6-greet-name.md
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
