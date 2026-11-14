#!/usr/bin/env bash
# approved-spec: the examples approved on the note "decision-record retires a
# wholly superseded record". E1 to E3 read the instruction that drives the
# agent. E4 and E6 run the record checker on a fixture folder. E5 holds already, so
# it lives in check-adr.test.sh as a plain regression test.
set -u
here="$(dirname "$0")"
skill="$here/../plugins/vicky-skills/skills/engineering/decision-record"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
. "$here/lib/skill-step.sh"
mark=$(skill_step "$skill/SKILL.md" 6)

# Given a record whose every force a new record overturns
# When the new record is written
# Then the new record's Consequences hold a line Retires ADR-NNNN with the reason, and the old record is deleted from the repo
check "E1 a record replaced in full is named by a Retires line and deleted" \
  'grep -q "Retires ADR-NNNN" <<<"$mark" && grep -q "delete the old record" <<<"$mark" && grep -q "Retires ADR-NNNN" "$skill/FORMAT.md"'

# Given a record a new record replaces only in part
# When the new record is written
# Then the old record gains an Amended or Superseded line in its Status and stays
check "E2 a record replaced in part gains a Status line and stays" \
  'grep -q "replaced in part" <<<"$mark" && grep -q "Amended by ADR-NNNN" <<<"$mark" && grep -q "Superseded by ADR-NNNN" <<<"$mark"'

# Given a wiki record whose every force a new record overturns
# When the new record is written
# Then the old page is tombstoned with a pointer to the new record, not deleted
check "E3 a wiki record replaced in full is tombstoned with a pointer" \
  'grep -q "tombstone" <<<"$mark" && grep -q "points at the new record" <<<"$mark"'

# Given a new record whose Consequences say Retires ADR-0003, and ADR-0003 still in the same folder
# When the record checker runs on the new record
# Then it fails and names ADR-0003 as retired but still present
# new_record <folder> <Retires line>: writes 0004-new-rule.md, a valid record
# whose Consequences open with the given line.
new_record() { sed "s|^RETIRES\$|$2|" > "$1/0004-new-rule.md" <<'R'
# ADR-0004: Keep the new rule

Category: Process.

## Status

Accepted 2026-11-14.

## Context

- F1: On 2026-11-13, the old force stopped holding.

## Decision

While F1 holds, the new rule applies.

## Consequences

RETIRES
No migration: nobody is left behind.

## Guard

Review only.
R
}
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
printf '# ADR-0003: Old rule\n' > "$dir/0003-old-rule.md"
new_record "$dir" "Retires ADR-0003: nothing it stated still holds."
out=$(bash "$skill/scripts/check-adr.sh" "$dir/0004-new-rule.md"); rc=$?
check "E4 the checker refuses a retired record left on disk" \
  '[ $rc -ne 0 ] && grep -q "ADR-0003 is retired but still present" <<<"$out"'

# Given a new record whose Consequences say Retires ADR-0003 with no reason after it
# When the record checker runs on the new record
# Then it fails and asks for the reason
bare=$(mktemp -d); trap 'rm -rf "$dir" "$bare"' EXIT
new_record "$bare" "Retires ADR-0003."
out=$(bash "$skill/scripts/check-adr.sh" "$bare/0004-new-rule.md"); rc=$?
check "E6 the checker refuses a Retires line with no reason" \
  '[ $rc -ne 0 ] && grep -q "Retires ADR-0003 gives no reason" <<<"$out"'

exit $fail
