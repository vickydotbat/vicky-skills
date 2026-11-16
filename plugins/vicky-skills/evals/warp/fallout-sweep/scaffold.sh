#!/usr/bin/env bash
# A star moves finesse from a feat to a weapon trait. No ticket names the
# auto-granted Weapon Finesse feat, which the change leaves doing nothing:
# only a fallout sweep of the code finds it before the build.
set -eu
git init -q -b main .
mkdir -p docs/agents tickets src
printf '# Tickets\n\nTickets are Markdown notes in `tickets/`. A ticket'"'"'s `Blocked by:` line names its blockers.\n' > docs/agents/issue-tracker.md
cat > tickets/STAR-1.md <<'T'
# Finesse comes from the weapon

Label: starchart:star

A weapon with the Finesse trait attacks with Dexterity when Dexterity is higher. The Weapon Finesse feat no longer decides it.

## Examples

- Given a rapier (Finesse) and Dexterity 16, Strength 10, when the character attacks, then the attack uses Dexterity. (approved)
T
cat > src/attack.js <<'J'
import { hasFeat } from "./feats.js";
export function attackAbility(c, weapon) {
  if (hasFeat(c, "WeaponFinesse") && weapon.light && c.dex > c.str) return "dex";
  return "str";
}
J
cat > src/feats.js <<'J'
export const AUTO_GRANTED = ["WeaponFinesse", "Unarmed"];
export function hasFeat(c, feat) { return AUTO_GRANTED.includes(feat) || c.feats.includes(feat); }
J
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
