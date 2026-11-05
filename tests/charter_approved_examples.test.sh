#!/usr/bin/env bash
# approved-spec: the examples approved on the note "Charter for the workflow".
# Each check is named after its example. E1 and E2 run the charter check on
# real and fixture skills; the rest read the instruction that drives the
# agent's behaviour.
set -u
root="$(dirname "$0")/../plugins/vicky-skills/skills"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
. "$(dirname "$0")/lib/skill-step.sh"; step() { skill_step "$1" "$2"; }

# Prints "<skill> <problem>" for each skill under $1 whose Charter: line is
# missing or names a line that $1/CHARTER.md lacks.
charter_check() {
  local dir=$1 f codes c
  codes=$(grep -oE '^- \*\*C[0-9]+\*\*' "$dir/CHARTER.md" 2>/dev/null | grep -oE 'C[0-9]+')
  for f in "$dir"/*/*/SKILL.md; do
    line=$(grep -v '^[[:space:]]*$' "$f" | tail -n 1 | grep '^Charter: ')
    grep -qE 'C[0-9]+' <<<"$line" || { echo "$f names no charter line"; continue; }
    for c in $(grep -oE 'C[0-9]+' <<<"$line"); do
      grep -qx "$c" <<<"$codes" || echo "$f names $c, which the charter lacks"
    done
  done
}

# Given any skill in the plugin
# When the tests run
# Then the skill names at least one charter line it serves
out=$(charter_check "$root")
check "E1 every skill names at least one charter line it serves" \
  '[ -z "$out" ]'
[ -z "$out" ] || echo "$out" | sed 's/^/     /'

# Given a skill that names charter line C9, which the charter does not hold
# When the tests run
# Then they fail, naming the skill and C9
fx=$(mktemp -d); trap 'rm -rf "$fx"' EXIT
mkdir -p "$fx/engineering/stray"
cp "$root/CHARTER.md" "$fx/CHARTER.md"
printf -- '---\nname: stray\n---\n# Stray\n\nCharter: C1, C9.\n' > "$fx/engineering/stray/SKILL.md"
check "E2 a skill naming C9, which the charter lacks, fails naming the skill and C9" \
  'charter_check "$fx" | grep -q "stray/SKILL.md names C9" && [ "$(charter_check "$fx" | wc -l)" -eq 1 ]'

fam="$root/productivity/familiar/SKILL.md"
# Given the familiar sees a snag in a watched session
# When it logs the snag on that session's note
# Then the line names the charter line the snag broke, or says no line fits
check "E3 the familiar's snag line names the charter line it broke, or says no line fits" \
  'step "$fam" 3 | grep -q "the charter line the snag broke" && step "$fam" 3 | grep -q "no line fits"'

# Given a session's note holds a snag that no charter line fits
# When the familiar closes that session's list
# Then it drafts a new charter line for you to approve
check "E4 closing a list with a snag no charter line fits drafts a new charter line for approval" \
  'step "$fam" 6 | grep -q "no line fits" && step "$fam" 6 | grep -q "draft a new charter line" && step "$fam" 6 | grep -q "red-pen"'

ex="$root/engineering/examples/SKILL.md"
# Given drafts for a feature with a table of entries, such as one icon per condition
# When the agent checks the drafts
# Then it drafts one more example for each entry or rule whose change alone would turn no drafted example red
check "E5 examples drafts one more example for each entry or rule whose change alone turns no draft red" \
  'step "$ex" 2 | grep -q "whose change alone would turn no drafted example red" && step "$ex" 2 | grep -q "each entry"'

# Given drafts that hold more than six rules
# When the agent hands them to you
# Then the page proposes splitting the star, with the rules each part keeps
check "E6 drafts with more than six rules go to the page with a proposed split" \
  'step "$ex" 3 | grep -q "more than six rules" && step "$ex" 3 | grep -q "the rules each part keeps"'

# Given one rule whose examples get their results for different reasons
# When the agent checks the drafts
# Then it drafts the hidden rule as a rule of its own, with its examples moved under it
check "E7 examples under one rule that differ in reason become a hidden rule of their own" \
  'step "$ex" 2 | grep -q "for different reasons" && step "$ex" 2 | grep -q "a rule of its own"'

do="$root/engineering/do/SKILL.md"
receipts=$(awk '/^## Receipts/{on=1; next} /^## /{on=0} on' "$do")
# Given do is about to run an example's test, red or green
# When it runs the test
# Then the receipt shows what it predicted, pass or fail and the failing line, above what the run showed
check "E8 do's receipt shows the prediction above each red and green run" \
  'grep -q "predicted" <<<"$receipts" && awk "/^predicted red:/{p=NR} /^red: /{r=NR} /^predicted green:/{q=NR} /^green: /{g=NR} END{exit !(p && p < r && q && q < g)}" <<<"$receipts" && step "$do" 3 | grep -q "write your prediction"'

# Given a run that differs from do's prediction
# When do reads the result
# Then it stops that example and finds the cause with never-lupus before it changes any code
check "E9 a run that differs from its prediction stops the example for never-lupus before any code changes" \
  'step "$do" 3 | grep -q "differs from the prediction" && step "$do" 3 | grep -q "never-lupus" && step "$do" 3 | grep -q "before you change any code"'
exit $fail
