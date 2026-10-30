#!/usr/bin/env bash
# true-names checks a decision record for what, category, when and why, an
# optional Superseded line, and nothing else, in at most 55 words.
# A record with the lines in order passes. A missing, repeated or extra
# line, the wrong order, a category off the list, a code name or a 56th word
# fails it.
set -u
script="$(dirname "$0")/../plugins/vicky-skills/skills/engineering/true-names/scripts/check-adr.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
what='# ADR-0007: Sound occlusion uses the physics raycasts'
cat='Category: Architecture.'
when='Decided 2026-10-30.'
why='Because the engine already casts rays each frame, and baked occlusion means a rebuild for every map.'
fail=0
pass() { printf '%s\n' "$2" > "$dir/r.md"; bash "$script" "$dir/r.md" >/dev/null || { echo "FAIL refused: $1"; fail=1; }; }
refuse() { printf '%s\n' "$2" > "$dir/r.md"; bash "$script" "$dir/r.md" >/dev/null && { echo "FAIL passed: $1"; fail=1; }; }
pass "what, category, when and why" "$what

$cat

$when

$why"
pass "the Other category" "$what
Category: Other.
$when
$why"
refuse "no what" "# Sound occlusion uses the physics raycasts
$cat
$when
$why"
refuse "a short number" "${what/ADR-0007/ADR-7}
$cat
$when
$why"
refuse "no category" "$what
$when
$why"
refuse "a category off the list" "$what
Category: Audio.
$when
$why"
refuse "two categories" "$what
Category: Architecture, Data.
$when
$why"
refuse "category after when" "$what
$when
$cat
$why"
refuse "no when" "$what
$cat
Decided last week.
$why"
refuse "no why" "$what
$cat
$when"
pass "a superseded record" "$what
$cat
$when
$why
Superseded by ADR-0009."
refuse "a line after Superseded" "$what
$cat
$when
$why
Superseded by ADR-0009.
$why"
refuse "Superseded before why" "$what
$cat
$when
Superseded by ADR-0009.
$why"
pass "a record superseded from another repository" "$what
$cat
$when
$why
Superseded by other-repo ADR-0009."
refuse "a repository name with spaces in it" "$what
$cat
$when
$why
Superseded by the other repo ADR-0009."
refuse "Superseded without a record number" "$what
$cat
$when
$why
Superseded by the new design."
refuse "an extra line" "$what
$cat
$when
$why
The rays are cached per emitter."
pad() { local s="" i; for ((i = 0; i < $1; i++)); do s+=" word"; done; printf '%s' "$s"; }
pass "55 words" "$what
$cat
$when
${why%.}$(pad 26)."
refuse "56 words" "$what
$cat
$when
${why%.}$(pad 27)."
refuse "a second why" "$what
$cat
$when
$why
$why"
refuse "why before when" "$what
$cat
$why
$when"
refuse "a backticked code name" "${what/physics raycasts/\`Physics.Raycast\`}
$cat
$when
$why"
printf '%s\n' "$what" "$cat" "$when" "$why" "## Context" "The rays are cached per emitter." "More text." > "$dir/r.md"
out=$(bash "$script" "$dir/r.md")
grep -q 'found: what category when why other(x3)' <<<"$out" || { echo "FAIL the report does not sum up the lines: $out"; fail=1; }
grep -q 'cached per emitter' <<<"$out" && { echo "FAIL the report repeats the record's text"; fail=1; }
bash "$script" "$dir/missing.md" >/dev/null && { echo "FAIL passed: a missing record"; fail=1; }
bash "$script" >/dev/null 2>&1; [ $? -eq 2 ] || { echo "FAIL no usage error without a record"; fail=1; }
[ $fail -eq 0 ] && echo "ok   check-adr passes what, category, when, why and Superseded in 55 words, and fails anything else"
exit $fail
