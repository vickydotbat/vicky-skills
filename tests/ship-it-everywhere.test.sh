#!/usr/bin/env bash
# Every path that writes a pull request body writes it with ship-it: the steps
# that open one, the steps that rewrite one, and the hint after a push. The
# phrases are an allowlist: a rewording that keeps the rule updates the phrase
# here in the same change.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
skills="$root/plugins/vicky-skills/skills"
fail=0
# has <name> <file> <line prefix or "-"> <phrase>: the phrase sits on that line
# (or anywhere in the file with "-").
has() {
  local text
  if [ "$3" = - ]; then text=$(cat "$2"); else text=$(grep -F -- "$3" "$2"); fi
  if grep -qF -- "$4" <<<"$text"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi
}
has "do opens its draft with ship-it" "$skills/engineering/do/SKILL.md" "2. **Make the examples red.**" 'open a **draft** pull request with `ship-it`'
has "a gamma-shift builder opens its draft with ship-it" "$skills/engineering/gamma-shift/SKILL.md" "2. Read the agent file" "with its body written by ship-it"
has "history-monks writes its rebase note with ship-it" "$skills/engineering/history-monks/SKILL.md" "7. **Land it.**" 'pull request body with `ship-it`, keeping its sections'
has "a gamma-shift builder adds its ticket with ship-it" "$skills/engineering/gamma-shift/SKILL.md" "2. Read the agent file" "add this ticket to its body with ship-it"
has "a stack writes each new body with ship-it" "$skills/engineering/stacked-branches/SKILL.md" - 'write each new pull request'"'"'s body with `ship-it`'
has "make-it-so rewrites the body to the template" "$skills/engineering/make-it-so/SKILL.md" "4. **Make it true.**" 'Rewrite the body to `ship-it`'"'"'s template'
has "settling keeps the template's sections" "$skills/engineering/make-it-so/SETTLE.md" "3. **Make the body true.**" 'keep `ship-it`'"'"'s sections'
has "the push hint names ship-it" "$root/plugins/vicky-skills/scripts/after-push.sh" - "with the ship-it skill"
has "ship-it has steps" "$skills/engineering/ship-it/SKILL.md" - "## Steps"
has "ship-it's template has the plan check line" "$skills/engineering/ship-it/SKILL.md" - "Plan check: <what it found>"
for f in "$skills"/engineering/first-contact/issue-tracker-*.md "$root/docs/agents/issue-tracker.md"; do
  has "$(basename "$f") switches the body check on" "$f" - "PR template: on"
done
exit $fail
