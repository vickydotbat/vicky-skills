#!/usr/bin/env bash
# approved-spec: the examples approved for "PM-5 The post-mortem check" on the
# Mortems star chart, and PM-6's two filing examples. Each runs a checker on a
# fixture in a throwaway git repo.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
pm="$here/../plugins/vicky-skills/skills/planning/post-mortem/scripts/check-post-mortem.sh"
fs="$here/../plugins/vicky-skills/skills/commands/lay-course/scripts/check-foreseen.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
git -C "$dir" init -q
mkdir -p "$dir/docs/post-mortems" "$dir/docs/agents"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
# postmortem <timeline line> <earlier incidents line> <follow-up line>
postmortem() {
  f="$dir/docs/post-mortems/2026-11-18-favourites-broke.md"
  printf '%s\n' '# Post-mortem: DM favourites broke after a row renumber' '' \
    '## Impact' '' 'By 2026-11-18, every stored DM favourite pointed at the wrong row.' '' \
    '## Timeline' '' '- 2026-11-17 20:10: an asset tidy-up renumbered the rows.' "$1" '' \
    '## Detection' '' 'A DM reported a favourite that spawned the wrong creature.' '' \
    '## Causes' '' '- Stored references held row numbers, not keys.' '' \
    '## Earlier incidents' '' "$2" '' \
    '## Lessons' '' '- A renumber is a breaking change to every stored reference.' '' \
    '## Follow-ups' '' "$3" > "$f"
  out=$(bash "$pm" "$f" 2>&1); rc=$?
}
good_time='- 2026-11-18 09:00: the favourites were remapped by key.'
good_earlier='- [[2026-10-02 Rows renumbered by the model folder]]'
good_follow='- Name rows by key: ADR-0007'

postmortem "$good_time" "$good_earlier" "$good_follow"
check "PM-5.0 a whole post-mortem passes" '[ $rc -eq 0 ]'

# Given a post-mortem whose follow-up Pin the row keys links nothing
# When the post-mortem check runs
# Then it fails, naming that follow-up
postmortem "$good_time" "$good_earlier" '- Pin the row keys'
check "PM-5.1 a follow-up with no link fails" '[ $rc -ne 0 ] && grep -q "Pin the row keys" <<<"$out"'

# Given a post-mortem whose Timeline has a line with no date
# When the post-mortem check runs
# Then it fails, naming that line
postmortem '- the favourites were remapped by key.' "$good_earlier" "$good_follow"
check "PM-5.2 an undated timeline line fails" '[ $rc -ne 0 ] && grep -q "the favourites were remapped by key" <<<"$out"'

# Given a post-mortem whose Earlier incidents reads None found, with no search named
# When the post-mortem check runs
# Then it fails, naming that section
postmortem "$good_time" 'None found.' "$good_follow"
check "PM-5.3 None found with no search fails" '[ $rc -ne 0 ] && grep -q "None found" <<<"$out" && grep -q "Earlier incidents" <<<"$out"'
postmortem "$good_time" 'None found: searched docs/post-mortems for renumber, row number and favourite.' "$good_follow"
check "PM-5.3b None found with its search passes" '[ $rc -eq 0 ]'

# Given a repo whose agent docs read Post-mortems: off
# When the post-mortem check runs
# Then it skips the repo
printf 'Post-mortems: off\n' > "$dir/docs/agents/domain.md"
postmortem '- no date here.' 'None found.' '- Pin the row keys'
check "PM-5.4 a repo with post-mortems off is skipped" '[ $rc -eq 0 ]'
rm "$dir/docs/agents/domain.md"

# chart <unknown unknowns lines>
chart() {
  f="$dir/chart.md"
  printf '%s\n' '# Star Chart: Row keys' '' '## Knowns' '' '### Unknown unknowns' '' \
    '- Riskiest star: [[Name rows by key]], covered by a one-session timebox' "$@" '' '## Black holes' '' 'None seen yet.' > "$f"
  out=$(bash "$fs" "$f" 2>&1); rc=$?
}
chart '- Foreseen 2026-11-18: a renumber breaks stored favourites, guarded by ADR-0007'
check "PM-6.0 a foreseen failure with a disposition passes" '[ $rc -eq 0 ]'

# Given a foreseen failure with no disposition
# When the chart is filed
# Then filing stops and names that failure
chart '- Foreseen 2026-11-18: a renumber breaks stored favourites'
check "PM-6.2 a foreseen failure with no disposition stops filing" '[ $rc -ne 0 ] && grep -q "a renumber breaks stored favourites" <<<"$out"'

# Given a plan with no foreseen failure
# When the pre-mortem step runs
# Then the chart holds one line: None foreseen, with the reason
chart '- None foreseen: the change only renames a heading.'
check "PM-6.3 None foreseen with its reason passes" '[ $rc -eq 0 ]'
chart
check "PM-6.3b a chart with no pre-mortem line stops filing" '[ $rc -ne 0 ] && grep -q "None foreseen" <<<"$out"'

# Given a repo whose agent docs read: Pre-mortems: off
# When a chart is filed with a foreseen failure that has no disposition
# Then filing goes ahead
printf 'Pre-mortems: off\n' > "$dir/docs/agents/domain.md"
chart '- Foreseen 2026-11-18: a renumber breaks stored favourites'
check "PM-6.4 a repo with pre-mortems off files anyway" '[ $rc -eq 0 ]'

exit $fail
