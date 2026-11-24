#!/usr/bin/env bash
# approved-spec: the examples the user ticked on 2026-11-24 for the skill
# graph: a file that lists each real hand-off between skills, checked against
# the skills' own text. Each check builds a small skills folder and a graph
# file, then runs the checker the way tests/run-all.sh does.
set -u
# check runs its condition through eval, so single quotes and variables set
# only for it are meant.
# shellcheck disable=SC2016,SC2034
root="$(cd "$(dirname "$0")/.." && pwd)"
graph="$root/plugins/vicky-skills/scripts/skill-graph.py"
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

# skill <group> <name> <step line>: a skill whose one step is the given line.
skill() {
  mkdir -p "$scratch/skills/$1/$2"
  printf -- '---\nname: %s\ndescription: x. Use when x.\n---\n# %s\n\n## Steps\n\n1. %s Done when it is done.\n' "$2" "$2" "$3" >"$scratch/skills/$1/$2/SKILL.md"
}
run() { python3 "$graph" check "$scratch/skills" "$scratch/GRAPH.tsv" >"$scratch/out" 2>&1; }

# Given a skill whose step says to run another skill, such as "run sentinels"
# And the skill graph file has no arrow for that hand-off
# When the maintainer runs tests/run-all.sh
# Then the skill graph test fails and names both skills
skill building 'do' 'Mutate the lines, then run `sentinels` on them.'
skill building sentinels 'Mutate the code.'
: >"$scratch/GRAPH.tsv"
run; code=$?
check "G1 a missing hand-off fails" '[ "$code" = 1 ]'
check "G1 the failure names both skills" 'grep -q "do.*sentinels" "$scratch/out"'

# Given a skill that only names another skill without handing off to it, such as "do runs this skill"
# And the skill graph file has no arrow for it
# When the maintainer runs tests/run-all.sh
# Then the skill graph test passes
rm -rf "$scratch/skills"
skill building 'do' 'Build the change.'
skill building sentinels 'Mutation test the code `do` changed.'
: >"$scratch/GRAPH.tsv"
run; code=$?
check "G2 a plain mention passes" '[ "$code" = 0 ]'

# Given the skill graph file has an arrow from one skill to another
# And no step of the first skill hands off to the second
# When the maintainer runs tests/run-all.sh
# Then the skill graph test fails and names the stale arrow
rm -rf "$scratch/skills"
skill building 'do' 'Build the change.'
skill building sentinels 'Mutate the code.'
printf 'do\tsentinels\n' >"$scratch/GRAPH.tsv"
run; code=$?
check "G3 a stale arrow fails" '[ "$code" = 1 ]'
check "G3 the failure names the stale arrow" 'grep -q "do.*sentinels" "$scratch/out"'

# Given every hand-off in the skills has its arrow and every arrow has its hand-off
# When the maintainer runs tests/run-all.sh
# Then the skill graph test passes
rm -rf "$scratch/skills"
skill building 'do' 'Mutate the lines, then run `sentinels` on them.'
skill building sentinels 'Mutate the code.'
printf 'do\tsentinels\n' >"$scratch/GRAPH.tsv"
run; code=$?
check "G4 a matching graph passes" '[ "$code" = 0 ]'

# The plugin's own graph matches its skills.
check "the plugin's GRAPH.tsv matches its skills" 'python3 "$graph" check "$root/plugins/vicky-skills/skills" "$root/plugins/vicky-skills/skills/GRAPH.tsv"'
exit "$fail"
