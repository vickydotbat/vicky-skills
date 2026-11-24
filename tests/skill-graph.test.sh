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
exit $fail
