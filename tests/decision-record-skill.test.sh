#!/usr/bin/env bash
# decision-record tells the agent to name each break a rule causes with its
# migration, to check a repo-template record with --template, and to point at
# a record by number instead of copying its rule into another file.
set -u
d="$(dirname "$0")/../plugins/vicky-skills/skills/engineering/decision-record"
fail=0
has() { grep -qF -- "$3" "$d/$2" || { echo "FAIL $1: $2 lacks: $3"; fail=1; }; }
lacks() { grep -qF -- "$3" "$d/$2" && { echo "FAIL $1: $2 still holds: $3"; fail=1; }; }
has "breaks named" SKILL.md "each break the rule causes"
has "no migration said aloud" SKILL.md "No migration:"
has "breaks in the template" FORMAT.md "each break (a stored form, public call or layout that changes)"
has "template records checked" SKILL.md "check-adr.sh --template <record>"
lacks "template records not skipped" SKILL.md "skip the check in step 5"
has "rules not copied" SKILL.md "Restate no record's rule in an agent file, README or doc"
has "point by number" SKILL.md "Point at the record by number instead"
[ $fail -eq 0 ] && echo "ok   decision-record names breaks, checks template records, and points at records instead of copying them"
exit $fail
