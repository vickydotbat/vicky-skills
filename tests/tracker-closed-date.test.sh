#!/usr/bin/env bash
# An Obsidian tracker counts a ticket closed by the date it closed, never by
# the last edit: an old done note edited later would count as closed again,
# with no opening beside it, and skew summit. Pins both copies of the
# operations: this repo's and first-contact's template.
set -u
r="$(cd "$(dirname "$0")/.." && pwd)"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
for f in "$r/docs/agents/issue-tracker.md" "$r/plugins/vicky-skills/skills/commands/first-contact/issue-tracker-obsidian.md"; do
  n=${f#"$r/"}
  check "$n: Close writes the closed date" 'grep -qF "| Close | Comment the reason, then set \`status: done\` and \`closed: YYYY-MM-DD\`. |" "$f"'
  check "$n: the frontmatter lists the closed field" 'grep -qE "^closed: +# " "$f"'
  check "$n: closed since counts by the closed date, and by the last edit only when a note has none" 'grep -F "**List items closed since <time>**" "$f" | grep -q "whose \`closed:\` date is on or after" && grep -F "**List items closed since <time>**" "$f" | grep -q "with no \`closed:\` date"'
done
exit $fail
