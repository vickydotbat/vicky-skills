#!/usr/bin/env bash
# An optional pick most players skip, whose options differ in data.
set -eu
git init -q -b main .
mkdir -p tickets data
printf 'id,name,blessing,cost,forbids\nsune,Sune,+1 Charisma,10 gold a month,none\ntempus,Tempus,+1 Strength,a weekly prayer,Wizard\noghma,Oghma,+1 Lore skill,none,Barbarian\n' > data/patrons.csv
printf -- '---
kind: star
---
# Patron page

In character creation, an optional Patron page lets the player pledge to one patron from data/patrons.csv, or to none. Most players skip it. Pressing Next saves the pick.

## Comments
' > tickets/4-page.md
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
