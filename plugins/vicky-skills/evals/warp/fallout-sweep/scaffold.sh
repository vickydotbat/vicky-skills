#!/usr/bin/env bash
# Only a fallout sweep finds the auto-grant: attack.js never imports the file that holds it.
set -eu
git init -q -b main .
mkdir -p docs/agents tickets src data
printf '# Tickets\n\nTickets are Markdown notes in `tickets/`. A ticket'"'"'s `Blocked by:` line names its blockers.\n' > docs/agents/issue-tracker.md
cat > tickets/STAR-1.md <<'T'
# Finesse comes from the weapon

Label: starchart:star

A weapon with the Finesse trait attacks with Dexterity when Dexterity is higher. The Weapon Finesse feat no longer decides it.

## Examples

- Given a rapier (Finesse) and Dexterity 16, Strength 10, when the character attacks, then the attack uses Dexterity. (approved)
T
cat > src/attack.js <<'J'
export function attackAbility(c, weapon) {
  if (c.feats.includes("WeaponFinesse") && weapon.light && c.dex > c.str) return "dex";
  return "str";
}
J
printf '{"everyCharacter": ["WeaponFinesse", "Unarmed"]}\n' > data/granted-feats.json
cat > src/newCharacter.js <<'J'
import granted from "../data/granted-feats.json" with { type: "json" };
export function newCharacter(stats) { return { ...stats, feats: [...granted.everyCharacter] }; }
J
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
