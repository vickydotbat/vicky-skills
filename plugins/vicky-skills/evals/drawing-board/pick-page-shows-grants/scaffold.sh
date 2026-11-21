#!/usr/bin/env bash
# A pick page whose options grant skills listed only in their data, never in their prose.
set -eu
git init -q -b main .
mkdir -p docs/agents tickets data
printf "# Tickets: notes\n\nTickets are Markdown notes in \`tickets/\`, one per ticket, with a \`kind:\` line (star, task, anomaly) in their frontmatter. A star is specified by its Examples; a task ends at a Done when line.\n" > docs/agents/issue-tracker.md
printf "id,name,description,icon,feat_id,skills\nsailor,Sailor,You grew up on the docks of a harbour town.,bg_sailor,1201,4;9\nacolyte,Acolyte,You served at a temple from childhood.,bg_acolyte,1202,2;6\nstreet,Street Urchin,You learned to live by your wits.,bg_street,1203,7;11\n" > data/backgrounds.csv
printf "id,label\n2,Lore\n4,Swim\n6,Heal\n7,Pick Pocket\n9,Rope Use\n11,Hide\n" > data/skills.csv
printf -- "---\nkind: star\n---\n# Backgrounds pick page\n\nIn character creation, a Backgrounds page lists the backgrounds in data/backgrounds.csv in two columns. The player clicks one to see it in a detail panel on the right, which shows its name, icon and description. Pressing Pick saves the choice to the character and adds a line to the creation ledger. The Summary page refuses to open until a background is picked.\n\n## Comments\n" > tickets/7-backgrounds-page.md
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
