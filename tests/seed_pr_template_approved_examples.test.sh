#!/usr/bin/env bash
# shellcheck disable=SC2319 # each $? is the outcome of the test line above it, which check grades
# approved-spec: the examples approved on the note "RS-S2 first-contact seeds
# the pull request template", on 2026-11-25. seed-pr-template.sh writes ship-it's
# seeded template into a repo that has none, in the forge's own place.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
seed="$root/plugins/vicky-skills/skills/commands/first-contact/scripts/seed-pr-template.sh"
template="$root/plugins/vicky-skills/skills/shipping/ship-it/SEEDED-TEMPLATE.md"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
fail=0
check() { if [ "$2" = 0 ]; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
# repo <name> <origin url>
repo() { git init -q -b main "$dir/$1"; git -C "$dir/$1" remote add origin "$2"; }

# Given a GitHub repo with no template
# When first-contact seeds one
# Then .github/pull_request_template.md is ship-it's seeded template, whole
repo hub https://github.com/o/r.git
bash "$seed" "$dir/hub" >/dev/null 2>&1
[ -f "$template" ] && cmp -s "$template" "$dir/hub/.github/pull_request_template.md"
check "RS-S2 E1 a GitHub repo gets the approved template whole" $?

# Given the approved template
# When the seeded template is read
# Then it holds every approved heading and the Closes line
for h in Status Summary Screenshots 'How to try it' 'More cases' Proof Risk Related; do grep -qx "## $h" "$template" 2>/dev/null || { echo "     no ## $h"; s=1; }; done
grep -q '^Closes <ticket>' "$template" 2>/dev/null || s=1
check "RS-S2 E6 ship-it's seeded template holds the approved headings" "${s:-0}"

# Given a Gitea repo
# When first-contact seeds a template
# Then the file is .gitea/PULL_REQUEST_TEMPLATE.md
repo tea https://forge.example/o/r.git
bash "$seed" "$dir/tea" >/dev/null 2>&1
[ -f "$dir/tea/.gitea/PULL_REQUEST_TEMPLATE.md" ] && [ ! -e "$dir/tea/.github" ]
check "RS-S2 E2 a Gitea repo gets .gitea/PULL_REQUEST_TEMPLATE.md" $?

# Given a repo that already has a template, at the forge's place or another
# When first-contact runs
# Then it leaves that one as it is and adds no second (the hub repo above,
# seeded by the same script, is the positive control)
i=0
for place in .github/pull_request_template.md docs/pull_request_template.md PULL_REQUEST_TEMPLATE.md .github/PULL_REQUEST_TEMPLATE.md; do
  i=$((i + 1)); n=has$i; repo "$n" https://github.com/o/r.git
  mkdir -p "$dir/$n/$(dirname "$place")"; echo mine >"$dir/$n/$place"
  bash "$seed" "$dir/$n" >/dev/null 2>&1
  count=$(find "$dir/$n" -path "$dir/$n/.git" -prune -o -iname pull_request_template.md -print | wc -l)
  [ "$(cat "$dir/$n/$place")" = mine ] && [ "$count" = 1 ] && [ -f "$dir/hub/.github/pull_request_template.md" ]
  check "RS-S2 E5 a template at $place is kept, with no second" $?
done

# Given a repo whose docs/agents file opts out of the seeded template
# When first-contact runs
# Then it writes no template
repo out https://github.com/o/r.git
mkdir -p "$dir/out/docs/agents"; printf 'Seed PR template: off\n' >"$dir/out/docs/agents/issue-tracker.md"
bash "$seed" "$dir/out" >/dev/null 2>&1
[ -f "$dir/hub/.github/pull_request_template.md" ] && [ ! -e "$dir/out/.github" ]
check "RS-S2 E9 an opted-out repo gets no template" $?

# Given a GitHub repo under an org
# When first-contact seeds a template
# Then it writes only the repo's own file
[ "$(find "$dir/hub" -path "$dir/hub/.git" -prune -o -type f -print | wc -l)" = 1 ]
check "RS-S2 E10 only the repo's own file is written" $?

exit $fail
