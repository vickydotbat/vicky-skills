#!/usr/bin/env bash
# approved-spec: review's Cause section, ticked on the drafts page
# 2026-11-17. The behaviour is the agent's, so each check reads the plugin
# files that drive it.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
skills="$root/plugins/vicky-skills/skills"
review="$skills/engineering/review/SKILL.md"
cause="$skills/engineering/review/CAUSE.md"
sk="$skills/engineering/assimilate/SKILL.md"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
has() { grep -qF -- "$2" "$1"; }

# Given a branch that claims to fix a problem
# When you review it
# Then the report has a Cause section beside Standards, Spec and Simplicity
# And it says whether the change fixes the cause or a symptom, and names the principle it serves
# And for a symptom it describes a design that makes the bad state impossible
check "E9 a branch that claims a fix gets a Cause section" \
  'has "$review" "\`## Cause\` when the branch claims to fix something" && has "$review" "[CAUSE.md](CAUSE.md)" && has "$cause" "Name the principle the change serves" && has "$cause" "the better way describes that design"'

# Given a branch that adds a feature and claims to fix nothing
# When you review it
# Then the report says Cause: no fix claimed, and has no Cause findings
check "E10 a branch that fixes nothing gets the no-fix line" \
  'has "$review" "\`Cause: no fix claimed\`"'

# Given the cause questions change in review
# When an agent next assimilates a pull request
# Then its verdict asks the changed questions, because both skills read them from one place
check "E11 assimilate reads the cause questions from review, and keeps no copy" \
  'has "$sk" "[CAUSE.md](../review/CAUSE.md)" && ( for q in "Reinvent the wheel" "**Is the principle met?**" "**Cause or symptom?**" "**Is there a better way?**"; do ! has "$sk" "$q" && ! has "$review" "$q" || exit 1; done )'
exit $fail
