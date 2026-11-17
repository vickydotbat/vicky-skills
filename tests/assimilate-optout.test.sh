#!/usr/bin/env bash
# Found work from review: a repo can switch off assimilate's Borg line and
# review's Cause section with a line first-contact writes.
#   Given a repo whose tracker doc says Claim voice: plain
#   When an agent claims someone else's pull request there
#   Then the claim comment has no Borg line
#   Given a repo whose tracker doc says Review cause: off
#   When a branch there claims a fix and is reviewed
#   Then the report has no Cause section
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
skills="$root/plugins/vicky-skills/skills"
sk="$skills/engineering/assimilate/SKILL.md"
review="$skills/engineering/review/SKILL.md"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
has() { grep -qF -- "$2" "$1"; }

check "assimilate drops the Borg line under Claim voice: plain" \
  'has "$sk" "\`Claim voice: plain\`"'
check "review drops the Cause section under Review cause: off" \
  'has "$review" "\`Review cause: off\`"'
for t in "$skills"/engineering/first-contact/issue-tracker-*.md "$root/docs/agents/issue-tracker.md"; do
  check "$(basename "$t") writes both opt-out lines" \
    'grep -qx "Claim voice: Borg" "$t" && grep -qx "Review cause: on" "$t"'
done
exit $fail
