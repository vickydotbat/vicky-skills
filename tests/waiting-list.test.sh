#!/usr/bin/env bash
# gamma-shift checks every waiting ticket, whoever it waits on, while the
# "waiting on you" list keeps only the user's. Every tracker template names
# both lists, and gamma-shift reads the whole one.
set -u
root="$(dirname "$0")/../plugins/vicky-skills/skills/engineering"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
check "every template lists all waiting tickets" \
  '(for t in "$root"/first-contact/issue-tracker-*.md; do grep -F "**List waiting tickets**" "$t" | grep -q "Waits on:" || exit 1; done)'
check "gamma-shift reads the whole waiting list" \
  'grep -q "its \"List waiting tickets\" command" "$root/gamma-shift/SKILL.md"'
check "gamma-shift counts only the user's waits in remind mode" \
  'grep -q "count only those whose \`Waits on:\` line names the user" "$root/gamma-shift/SKILL.md"'
exit $fail
