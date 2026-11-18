#!/usr/bin/env bash
# approved-spec: the examples approved on the note "Charter for the workflow".
# E1 and E2 run the charter check on real and fixture skills: a form lint,
# like skill-steps. The checks that read skill wording are gone, since prose
# is never tested.
set -u
root="$(dirname "$0")/../plugins/vicky-skills/skills"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

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

# Given a skill that names charter line C99, which the charter does not hold
# When the tests run
# Then they fail, naming the skill and C99
fx=$(mktemp -d); trap 'rm -rf "$fx"' EXIT
mkdir -p "$fx/engineering/stray"
cp "$root/CHARTER.md" "$fx/CHARTER.md"
printf -- '---\nname: stray\n---\n# Stray\n\nCharter: C1, C99.\n' > "$fx/engineering/stray/SKILL.md"
check "E2 a skill naming C99, which the charter lacks, fails naming the skill and C99" \
  'charter_check "$fx" | grep -q "stray/SKILL.md names C99" && [ "$(charter_check "$fx" | wc -l)" -eq 1 ]'

exit $fail
