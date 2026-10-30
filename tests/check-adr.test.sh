#!/usr/bin/env bash
# true-names checks a decision record for what, when and why, and nothing else.
# A record with the three lines in order passes. A missing, repeated or extra
# line, the wrong order or a code name fails it.
set -u
script="$(dirname "$0")/../plugins/vicky-skills/skills/engineering/true-names/scripts/check-adr.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
what='# ADR-0007: Sound occlusion uses the physics raycasts'
when='Decided 2026-10-30.'
why='Because the engine already casts rays each frame, and baked occlusion means a rebuild for every map.'
fail=0
pass() { printf '%s\n' "$2" > "$dir/r.md"; bash "$script" "$dir/r.md" >/dev/null || { echo "FAIL refused: $1"; fail=1; }; }
refuse() { printf '%s\n' "$2" > "$dir/r.md"; bash "$script" "$dir/r.md" >/dev/null && { echo "FAIL passed: $1"; fail=1; }; }
pass "what, when and why" "$what

$when

$why"
refuse "no what" "# Sound occlusion uses the physics raycasts
$when
$why"
refuse "a short number" "${what/ADR-0007/ADR-7}
$when
$why"
refuse "no when" "$what
Decided last week.
$why"
refuse "no why" "$what
$when"
refuse "an extra line" "$what
$when
$why
Superseded by ADR-0009."
refuse "a second why" "$what
$when
$why
$why"
refuse "why before when" "$what
$why
$when"
refuse "a backticked code name" "${what/physics raycasts/\`Physics.Raycast\`}
$when
$why"
bash "$script" "$dir/missing.md" >/dev/null && { echo "FAIL passed: a missing record"; fail=1; }
bash "$script" >/dev/null 2>&1; [ $? -eq 2 ] || { echo "FAIL no usage error without a record"; fail=1; }
[ $fail -eq 0 ] && echo "ok   check-adr passes what, when, why and fails anything else"
exit $fail
