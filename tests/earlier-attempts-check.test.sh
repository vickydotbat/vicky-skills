#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2034 # check() evals each condition after the run it reads
# A star chart lists the earlier attempts at its symptom, as STAR-CHART.md's
# "Earlier attempts" says: each one linked, or a None found line that names
# its search. The check refuses a chart that holds neither.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
ea="$here/../plugins/vicky-skills/skills/commands/lay-course/scripts/check-earlier-attempts.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
git -C "$dir" init -q
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
chart() { { printf '%s\n' '# Star Chart: x' '' '## Mission' '' 'x' ''; [ $# -gt 0 ] && printf '%s\n' '## Earlier attempts' '' "$@" ''; printf '%s\n' '## Knowns' '' '- x'; } > "$dir/chart.md"; }

bash "$ea" >/dev/null 2>&1; rc=$?
check "no file is a usage error" '[ $rc -eq 2 ]'
out=$(bash "$ea" "$dir/missing.md"); rc=$?
check "a file it cannot read fails" '[ $rc -eq 1 ] && grep -q "cannot read" <<<"$out"'

chart
out=$(bash "$ea" "$dir/chart.md"); rc=$?
check "a chart with no Earlier attempts section fails and names the section" '[ $rc -eq 1 ] && grep -q "no ## Earlier attempts section" <<<"$out"'
chart ''
out=$(bash "$ea" "$dir/chart.md"); rc=$?
check "an empty Earlier attempts section fails" '[ $rc -eq 1 ] && grep -q "Earlier attempts is empty" <<<"$out"'
chart 'None found.'
out=$(bash "$ea" "$dir/chart.md"); rc=$?
check "a None found line that names no search fails" '[ $rc -eq 1 ] && grep -q "names no search" <<<"$out"'
chart '- the hook got a fix last week'
out=$(bash "$ea" "$dir/chart.md"); rc=$?
check "an attempt with no link fails and quotes the line" '[ $rc -eq 1 ] && grep -q "links nothing: - the hook got a fix last week" <<<"$out"'

chart 'None found: searched merged pull requests and closed tickets for flaky, CI red.'
bash "$ea" "$dir/chart.md" >/dev/null; rc=$?
check "a None found line with its search passes" '[ $rc -eq 0 ]'
chart '- #12: the lint job runs from one script locally and in CI, and the symptom came back in the test job.' '- !8: the pre-push hook runs CI'"'"'s own check.' '- PROJ-3: found work, closed.' '- https://example.invalid/pulls/9: reverted.'
bash "$ea" "$dir/chart.md" >/dev/null; rc=$?
check "attempts linked by number, ticket key or address pass" '[ $rc -eq 0 ]'
chart '- #41: one script on both sides, for one job.' 'This chart does the same for every job.'
bash "$ea" "$dir/chart.md" >/dev/null; rc=$?
check "a prose line beside a linked attempt passes" '[ $rc -eq 0 ]'
chart 'The hook got a fix last week.'
out=$(bash "$ea" "$dir/chart.md"); rc=$?
check "prose with no linked attempt and no None found line fails" '[ $rc -eq 1 ] && grep -q "Earlier attempts is empty" <<<"$out"'

chart '- [[2026-11-01 Fix flaky hook]]: fixed the hook, and the symptom came back.'
bash "$ea" "$dir/chart.md" >/dev/null; rc=$?
check "an attempt linked by vault note passes" '[ $rc -eq 0 ]'
chart '- None found: searched closed tickets for flaky.'
bash "$ea" "$dir/chart.md" >/dev/null; rc=$?
check "a None found line written as a bullet passes" '[ $rc -eq 0 ]'
chart '- UTF-8 handling was tweaked last week.'
out=$(bash "$ea" "$dir/chart.md"); rc=$?
check "a key-shaped word inside prose is no link" '[ $rc -eq 1 ] && grep -q "links nothing" <<<"$out"'
chart '- https://'
bash "$ea" "$dir/chart.md" >/dev/null; rc=$?
check "a bare scheme is no link" '[ $rc -eq 1 ]'
chart 'None found: research pending.'
out=$(bash "$ea" "$dir/chart.md"); rc=$?
check "a None found line must say where it searched and for what" '[ $rc -eq 1 ] && grep -q "names no search" <<<"$out"'
chart 'None found: searched closed tickets for flaky.' '- #12: fixed the hook, and the symptom came back.'
out=$(bash "$ea" "$dir/chart.md"); rc=$?
check "None found beside a linked attempt fails" '[ $rc -eq 1 ] && grep -q "both" <<<"$out"'
printf '## Earlier attempts \r\n\r\n- #12: fixed the hook, and the symptom came back.\r\n' > "$dir/chart.md"
bash "$ea" "$dir/chart.md" >/dev/null; rc=$?
check "CRLF line ends and a trailing space on the heading pass" '[ $rc -eq 0 ]'

mkdir -p "$dir/docs/agents"; printf 'Earlier attempts: off\n' > "$dir/docs/agents/domain.md"
chart
bash "$ea" "$dir/chart.md" >/dev/null; rc=$?
check "a repo whose agent docs read Earlier attempts: off is skipped" '[ $rc -eq 0 ]'
exit $fail
