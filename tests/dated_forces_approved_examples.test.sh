#!/usr/bin/env bash
# approved-spec: the examples approved for "PM-1 Every force carries a date"
# and "PM-2 An incident force links its incident" on the Mortems star chart.
# Each runs the record checker on one record in the current shape.
set -u
here="$(dirname "$0")"
script="$here/../plugins/vicky-skills/skills/planning/decision-record/scripts/check-adr.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
# record <accepted date> <context lines> <decision line> [later status line]
record() {
  local status="Accepted $1."
  [ -n "${4:-}" ] && status="$status
$4"
  printf '%s\n' '# ADR-0012: Keep the gate short' '' 'Category: Tooling.' '' '## Status' '' "$status" '' \
    '## Context' '' "$2" '' '## Decision' '' "$3" '' '## Consequences' '' 'Docs changes stop paying the full gate.' '' \
    '## Guard' '' 'Review only.' > "$dir/0012-keep-the-gate-short.md"
  out=$(bash "$script" "$dir/0012-keep-the-gate-short.md"); rc=$?
}

# PM-1
# Given a decision record whose force reads: F1: The engine drops rows.
# When the record check runs on it
# Then it fails with: F1 has no date
record 2026-11-20 '- F1: The engine drops rows.' 'While F1 holds, rows are named by key.'
check "PM-1.1 an undated force fails" '[ $rc -ne 0 ] && grep -q "F1 has no date" <<<"$out"'

# Given the same force reading: F1: By 2026-11-18, the engine dropped rows.
# When the record check runs on it
# Then it passes
record 2026-11-20 '- F1: By 2026-11-18, the engine dropped rows.' 'While F1 holds, rows are named by key.'
check "PM-1.2 a dated force passes" '[ $rc -eq 0 ]'

# Given a kept record whose force reads: F1: The engine drops rows.
# And its Status gained: Superseded by ADR-0042 on 2026-11-20: F1 no longer holds.
# When the record check runs on it
# Then it passes, since a kept record can't gain a date
record 2026-11-10 '- F1: The engine drops rows.' 'While F1 holds, rows are named by key.' 'Superseded by ADR-0042 on 2026-11-20: F1 no longer holds.'
check "PM-1.3 a kept record keeps its undated force" '[ $rc -eq 0 ]'

# PM-2
# Given a force tagged incident with no link: F1 (incident): By 2026-11-02, the gate ran 11 minutes.
# When the record check runs on it
# Then it fails with: F1 is tagged incident but links no ticket or post-mortem
record 2026-11-20 '- F1 (incident): By 2026-11-02, the gate ran 11 minutes.' 'While F1 holds, the gate stays under ten minutes.'
check "PM-2.1 an incident force with no link fails" '[ $rc -ne 0 ] && grep -q "F1 is tagged incident but links no ticket or post-mortem" <<<"$out"'

# Given the force reading: F1 (incident GAME-2217): By 2026-11-02, the gate ran 11 minutes.
# When the record check runs on it
# Then it passes
record 2026-11-20 '- F1 (incident GAME-2217): By 2026-11-02, the gate ran 11 minutes.' 'While F1 holds, the gate stays under ten minutes.'
check "PM-2.2 an incident force with its ticket passes" '[ $rc -eq 0 ]'

# Given a force tagged foreseen with no link: F2 (foreseen): By 2026-11-18, a missed path could have merged unchecked.
# When the record check runs on it
# Then it passes
record 2026-11-20 '- F1: By 2026-11-02, the gate ran 11 minutes.
- F2 (foreseen): By 2026-11-18, a missed path could have merged unchecked.' 'While F1 and F2 hold, an unmapped path runs every check.'
check "PM-2.3 a foreseen force needs no link" '[ $rc -eq 0 ]'

# Given a force tagged: F1 (urgent): By 2026-11-02, the gate ran 11 minutes.
# When the record check runs on it
# Then it fails with: F1 has an unknown tag: use (incident <ticket>) or (foreseen)
record 2026-11-20 '- F1 (urgent): By 2026-11-02, the gate ran 11 minutes.' 'While F1 holds, the gate stays under ten minutes.'
check "PM-2.4 an unknown tag fails" '[ $rc -ne 0 ] && grep -qF "F1 has an unknown tag: use (incident <ticket>) or (foreseen)" <<<"$out"'

# Given a force tagged: F1 (incident GAME-2217): By 2026-11-02, the gate ran 11 minutes.
# And a Decision that reads: While F1 holds, the gate stays under ten minutes.
# When the record check runs on it
# Then it passes
record 2026-11-20 '- F1 (incident GAME-2217): By 2026-11-02, the gate ran 11 minutes.' 'While F1 holds, the gate stays under ten minutes.'
check "PM-2.5 a Decision may cite a tagged force" '[ $rc -eq 0 ]'

exit $fail
