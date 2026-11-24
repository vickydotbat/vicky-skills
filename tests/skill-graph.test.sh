#!/usr/bin/env bash
# skill-graph.py's edges: list prints each hand-off, and a wrong call is a
# usage error that exits 2.
# The skill files hold backticks on purpose, so single quotes keep them literal.
# shellcheck disable=SC2016
set -u
graph="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/skill-graph.py"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
fail=0
expect() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: want '$2', got '$3'"; fail=1; fi; }
mkdir -p "$dir/s/building/do" "$dir/s/building/sentinels"
printf -- '---\nname: do\n---\n1. Then run `sentinels` on it.\n' >"$dir/s/building/do/SKILL.md"
printf -- '---\nname: sentinels\n---\n1. Mutate.\n' >"$dir/s/building/sentinels/SKILL.md"
expect "list prints each hand-off, tab-separated" "$(printf 'do\tsentinels')" "$(python3 "$graph" list "$dir/s")"
expect "list exits 0" 0 "$(python3 "$graph" list "$dir/s" >/dev/null; echo $?)"
expect "no arguments is a usage error" 2 "$(python3 "$graph" 2>/dev/null; echo $?)"
expect "list with an extra argument is a usage error" 2 "$(python3 "$graph" list "$dir/s" x 2>/dev/null; echo $?)"
expect "check without a graph file is a usage error" 2 "$(python3 "$graph" check "$dir/s" 2>/dev/null; echo $?)"
expect "an unknown verb with four arguments is a usage error" 2 "$(python3 "$graph" draw "$dir/s" x 2>/dev/null; echo $?)"
expect "a usage error prints the usage" 1 "$(python3 "$graph" 2>&1 | grep -c 'skill-graph.py check')"
# Shapes the deathmatch of 2026-11-24 found the first pattern misread.
mk() { mkdir -p "$dir/t/building/$1"; printf -- '---\nname: %s\n---\n%s\n' "$1" "$2" >"$dir/t/building/$1/SKILL.md"; }
for s in b c e f h i; do mk "$s" '1. Work.'; done
mk a 'Never run `b` here. Do not start `c`.'
expect "a negated verb is no hand-off" "" "$(python3 "$graph" list "$dir/t" | grep '^a')"
mk d 'Run `b` and `c`, or run `e`/`f`.'
expect "each skill in a list after the verb is a hand-off" "b c e f" "$(python3 "$graph" list "$dir/t" | awk '$1=="d"{print $2}' | paste -sd' ')"
mk g 'When `h` runs `i`, wait.'
expect "a verb whose subject is another skill is no hand-off" "" "$(python3 "$graph" list "$dir/t" | grep '^g')"
mk j 'Dispatch `b`, load `c`, follow `e`, then `f`.'
expect "dispatch, load, follow and then hand off" "b c e f" "$(python3 "$graph" list "$dir/t" | awk '$1=="j"{print $2}' | paste -sd' ')"
mk k '1. Work.'; printf 'Then run `h` on it.\n' >"$dir/t/building/k/STEPS.md"
expect "a hand-off in a skill's other file counts for that skill" "$(printf 'k\th')" "$(python3 "$graph" list "$dir/t" | grep '^k')"
mkdir -p "$dir/t/building/m"; printf -- '---\nname: m\ndescription: Use before you run `b`.\n---\n1. Work.\n' >"$dir/t/building/m/SKILL.md"
expect "the frontmatter's description is no hand-off" "" "$(python3 "$graph" list "$dir/t" | grep '^m')"
# Shapes the holds opponent found on the fixed head.
mk n 'Do not, under any circumstances, run `b`.'
expect "a negation earlier in the clause blocks the hand-off" "" "$(python3 "$graph" list "$dir/t" | grep '^n')"
mk p "$(printf 'Run\n`b` after.')"
expect "a hand-off wrapped across lines counts" "$(printf 'p\tb')" "$(python3 "$graph" list "$dir/t" | grep '^p')"
mk r 'Run `B`.'
expect "a name in the wrong case is no hand-off" "" "$(python3 "$graph" list "$dir/t" | grep '^r')"
expect "a missing graph file is a usage error" 2 "$(python3 "$graph" check "$dir/t" "$dir/none.tsv" 2>/dev/null; echo $?)"
expect "a missing graph file is named" 1 "$(python3 "$graph" check "$dir/t" "$dir/none.tsv" 2>&1 | grep -c 'no graph file at')"
python3 "$graph" list "$dir/s" >"$dir/g.tsv"; printf '# from\tto\n' | cat - "$dir/g.tsv" >"$dir/h.tsv"
expect "a comment line in the graph is skipped" 0 "$(python3 "$graph" check "$dir/s" "$dir/h.tsv" >/dev/null; echo $?)"
exit $fail
