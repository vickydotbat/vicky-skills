#!/usr/bin/env bash
# check-adr checks a decision record: what, category, when, then a Brief and a
# Rationale section of one paragraph each, in at most 100 words; or the older
# four-line shape with a Because line, in at most 55. Both take an optional
# Superseded line and nothing else. A missing, repeated or extra line or
# section, the wrong order, a mix of the two shapes, a category off the list,
# a code name or a word past the limit fails it.
set -u
script="$(dirname "$0")/../plugins/vicky-skills/skills/engineering/decision-record/scripts/check-adr.sh"
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
grep -q 'found: what category when why context other(x2)' <<<"$out" || { echo "FAIL the report does not sum up the lines: $out"; fail=1; }
grep -q 'cached per emitter' <<<"$out" && { echo "FAIL the report repeats the record's text"; fail=1; }
bash "$script" "$dir/missing.md" >/dev/null && { echo "FAIL passed: a missing record"; fail=1; }
bash "$script" >/dev/null 2>&1; [ $? -eq 2 ] || { echo "FAIL no usage error without a record"; fail=1; }
brief='## Brief

Sound occlusion reuses the raycasts the physics engine already casts each frame.'
rationale='## Rationale

The engine casts rays every frame anyway. Baked occlusion would mean a rebuild
for every map, and a stale bake goes unnoticed until a player hears it.'
pass "what, category, when, Brief and Rationale" "$what

$cat

$when

$brief

$rationale"
pass "a Rationale that starts with Because" "$what
$cat
$when
$brief
## Rationale
Because the engine casts rays every frame anyway."
pass "a Brief and Rationale record superseded" "$what
$cat
$when
$brief
$rationale

Superseded by other-repo ADR-0009."
refuse "no Brief" "$what
$cat
$when
$rationale"
refuse "no Rationale" "$what
$cat
$when
$brief"
refuse "Rationale before Brief" "$what
$cat
$when
$rationale
$brief"
refuse "an empty Brief" "$what
$cat
$when
## Brief
$rationale"
refuse "two paragraphs in the Brief" "$what
$cat
$when
$brief

A second paragraph.
$rationale"
refuse "two paragraphs in the Rationale" "$what
$cat
$when
$brief
$rationale

A second paragraph."
refuse "Because mixed with Brief and Rationale" "$what
$cat
$when
$why
$brief
$rationale"
refuse "Because after the sections" "$what
$cat
$when
$brief
$rationale

$why"
refuse "a third section" "$what
$cat
$when
$brief
$rationale
## Context
More text."
refuse "a backticked code name in the Brief" "$what
$cat
$when
${brief/raycasts/\`Physics.Raycast\`}
$rationale"
pass "100 words" "$what
$cat
$when
$brief
## Rationale
Because$(pad 71)."
refuse "101 words" "$what
$cat
$when
$brief
## Rationale
Because$(pad 72)."
# The current shape: Status, Context forces, a While decision, Consequences, Guard.
nwhat='# ADR-0012: Reuse the physics raycasts for sound occlusion'
st='## Status

Accepted 2026-11-13.'
ctx='## Context

- F1: By 2026-11-01, the engine cast rays for physics every frame.
- F2: Baked occlusion had needed a rebuild for every map.'
dec='## Decision

While F1 and F2 hold, sound occlusion reuses the physics raycasts.'
con='## Consequences

No bake step ships. A frame with no physics casts no sound rays either.'
grd='## Guard

Review only.'
rec() { printf '%s\n\n' "$nwhat" "$cat" "${1:-$st}" "${2:-$ctx}" "${3:-$dec}" "${4:-$con}" "${5:-$grd}"; }
pass "the current shape" "$(rec)"
pass "a Decision paragraph that wraps over two lines" "$(rec "" "" '## Decision

While F1 and F2 hold, sound occlusion
reuses the physics raycasts.')"
pass "a superseded current record" "$(rec "$st
Superseded by ADR-0013 on 2026-12-01: F2 no longer holds.")"
pass "an amended then superseded record" "$(rec "$st
Amended by ADR-0013 on 2026-12-01.
Superseded by platform ADR-0020 on 2027-01-05: F1 no longer holds.")"
refuse "Superseded naming a force Context lacks" "$(rec "$st
Superseded by ADR-0013 on 2026-12-01: F9 no longer holds.")"
refuse "Superseded with no date" "$(rec "$st
Superseded by ADR-0013.")"
refuse "Status without Accepted" "$(rec '## Status

Proposed.')"
refuse "a Status edit in prose" "$(rec "$st
We changed our minds.")"
refuse "a Context line that is no force" "$(rec "$ctx
The engine is fast.")"
refuse "a repeated force number" "$(rec "" "$ctx
- F1: Again.")"
refuse "a Decision without While" "$(rec "" "" '## Decision

Sound occlusion reuses the physics raycasts, given F1.')"
refuse "a Decision citing no force" "$(rec "" "" '## Decision

While the engine casts rays, sound occlusion reuses them.')"
refuse "a Decision citing a force Context lacks" "$(rec "" "" '## Decision

While F3 holds, sound occlusion reuses the physics raycasts.')"
refuse "no Guard" "$(printf '%s\n\n' "$nwhat" "$cat" "$st" "$ctx" "$dec" "$con")"
refuse "two paragraphs in the Guard" "$(rec "" "" "" "" "$grd

A lint, later.")"
refuse "Guard before Consequences" "$(printf '%s\n\n' "$nwhat" "$cat" "$st" "$ctx" "$dec" "$grd" "$con")"
refuse "a Decided line in the current shape" "$(printf '%s\n\n' "$nwhat" "$cat" "$when" "$st" "$ctx" "$dec" "$con" "$grd")"
refuse "a backticked name in the Decision" "$(rec "" "" '## Decision

While F1 holds, sound occlusion calls `Physics.Raycast`.')"
base=$(rec "" "" "" "## Consequences

x" | wc -w)
pass "180 words" "$(rec "" "" "" "## Consequences

No bake step$(pad $((180 - base - 2)))")"
refuse "181 words" "$(rec "" "" "" "## Consequences

No bake step$(pad $((181 - base - 2)))")"
tpl='# 2. Keep money as integer cents

## Decision

While binary floats lose cents, money is integer cents.

## Consequences

Sums are exact. No migration: old ledgers stop loading.

## Guard

A test fails on a float in any module.'
tpass() { printf '%s\n' "$2" > "$dir/t.md"; bash "$script" --template "$dir/t.md" >/dev/null || { echo "FAIL refused: $1"; fail=1; }; }
trefuse() { printf '%s\n' "$2" > "$dir/t.md"; bash "$script" --template "$dir/t.md" >/dev/null && { echo "FAIL passed: $1"; fail=1; }; }
tpass "a template record" "$tpl"
trefuse "a template record with code" "$tpl
See \`ledger.py\`."
trefuse "a template record with no While" "${tpl/While binary floats lose cents, money/Money}"
trefuse "a template record with no Consequences" "${tpl/Consequences/Effects}"
trefuse "a template record with no Guard" "${tpl/Guard/Checks}"
trefuse "a template record past 180 words" "$tpl$(pad 180)"
rm -f "$dir/t.md"; bash "$script" --template "$dir/t.md" >/dev/null && { echo "FAIL passed: a missing template record"; fail=1; }
[ "$(bash "$script" "$dir/t.md")" = "$dir/t.md: cannot read" ] || { echo "FAIL a missing record is named once as unreadable"; fail=1; }
bash "$script" --template >/dev/null 2>&1; [ $? -eq 2 ] || { echo "FAIL --template with no record should exit 2"; fail=1; }
[ $fail -eq 0 ] && echo "ok   check-adr passes the current and both older shapes within their word limits, and fails anything else, and --template checks a repo template's shape-free rules"
# Regression (holds since the Retires check landed): a Retires line whose
# record is gone from the folder passes.
rd=$(mktemp -d)
printf '%s\n' '# ADR-0004: Keep the new rule' '' 'Category: Process.' '' '## Status' '' 'Accepted 2026-11-14.' '' '## Context' '' '- F1: On 2026-11-13, the old force stopped holding.' '' '## Decision' '' 'While F1 holds, the new rule applies.' '' '## Consequences' '' 'Retires ADR-0003: nothing it stated still holds.' '' '## Guard' '' 'Review only.' > "$rd/0004-new-rule.md"
bash "$script" "$rd/0004-new-rule.md" >/dev/null || { echo "FAIL refused: a Retires line whose record is gone"; fail=1; }
printf '# ADR-0003: Old\n' > "$rd/0003-old.md"
bash "$script" "$rd/0004-new-rule.md" >/dev/null && { echo "FAIL passed: a Retires line whose record is still present"; fail=1; }
printf '# ADR-0005: Other\n' > "$rd/0005-other.md"; rm "$rd/0003-old.md"
bash "$script" "$rd/0004-new-rule.md" >/dev/null || { echo "FAIL refused: another record in the folder is not the retired one"; fail=1; }
rm -rf "$rd"

exit $fail
