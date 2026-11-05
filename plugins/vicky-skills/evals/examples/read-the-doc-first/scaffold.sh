#!/usr/bin/env bash
# A game repo whose stacking rule lives in a system doc the ticket never quotes.
set -eu
git init -q -b main .
mkdir -p docs/systems tickets
printf '# Combat\n\n## Attack rolls\n\nRoll a d20 and add your bonuses.\n\n## Same-type bonuses\n\nTwo bonuses of the same type never stack: the higher one applies.\n' > docs/systems/combat.md
printf '# Tickets: notes\n\nTickets are Markdown notes in `tickets/`.\n' > docs/issue-tracker.md
mkdir -p docs/agents && cp docs/issue-tracker.md docs/agents/issue-tracker.md
printf '# Two bards inspire the same party\n\nWhen two bards both inspire the party, each member gets a morale bonus to attack from each bard.\n\n## Comments\n' > tickets/7-two-bards.md
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
