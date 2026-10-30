#!/usr/bin/env bash
# true-names checks a decision record for what, when and why, an optional
# Superseded line, and nothing else, in at most 50 words.
# A record with the lines in order passes. A missing, repeated or extra
# line, the wrong order, a code name or a 51st word fails it.
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
pass "a superseded record" "$what
$when
$why
Superseded by ADR-0009."
refuse "a line after Superseded" "$what
$when
$why
Superseded by ADR-0009.
$why"
refuse "Superseded before why" "$what
$when
Superseded by ADR-0009.
$why"
refuse "Superseded without a record number" "$what
$when
$why
Superseded by the new design."
refuse "an extra line" "$what
$when
$why
The rays are cached per emitter."
pad() { local s="" i; for ((i = 0; i < $1; i++)); do s+=" word"; done; printf '%s' "$s"; }
pass "50 words" "$what
$when
${why%.}$(pad 23)."
refuse "51 words" "$what
$when
${why%.}$(pad 24)."
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
[ $fail -eq 0 ] && echo "ok   check-adr passes what, when, why and Superseded in 50 words, and fails anything else"
exit $fail
