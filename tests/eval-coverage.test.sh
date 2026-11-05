#!/usr/bin/env bash
# eval-coverage.sh's edges: a case.yaml grader list counts, a results folder is
# no case, a skills entry may be one string, and bad input exits 2.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
cmd="$root/tests/eval-coverage.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
fail=0
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got '$3', want '$2'"; fail=1; fi; }
code() { bash "$cmd" "$@" >/dev/null 2>&1; echo $?; }
p="$dir/p"; mkdir -p "$p/.claude-plugin" "$p/evals/solo/one" "$p/evals/solo/results/old"
echo '{"name":"p","skills":"./skills/engineering/solo/"}' > "$p/.claude-plugin/plugin.json"
printf 'schema_version: "1.1"\nname: one\ngraders:\n  - name: g\n    type: regex\n    pattern: x\n' > "$p/evals/solo/one/case.yaml"
printf -- '---\n---\nold run\n' > "$p/evals/solo/results/old/prompt.md"
check "a case.yaml grader list counts, and one skills string is read" 0 "$(code "$p")"
check "a results folder is no case" "" "$(bash "$cmd" "$p" | grep results)"
sed -i '/^graders:/,$d' "$p/evals/solo/one/case.yaml"
check "a case.yaml with no graders fails" 1 "$(code "$p")"
echo '{"name":"p"}' > "$p/.claude-plugin/plugin.json"
check "a plugin with no skills list checks only its cases" 1 "$(code "$p")"
check "no argument exits 2" 2 "$(code)"
check "two arguments exit 2" 2 "$(code "$p" "$p")"
check "a folder with no manifest exits 2" 2 "$(code "$dir")"
exit $fail
