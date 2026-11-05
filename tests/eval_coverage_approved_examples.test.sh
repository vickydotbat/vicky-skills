#!/usr/bin/env bash
# approved-spec: the examples the user ticked on 2026-11-05 for "Skill evals -
# coverage is required": the coverage check fails a skill with no eval case,
# and a case with no grader, naming each. It reads the files only and starts
# no model, so CI can run it.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
check_cmd="$root/tests/eval-coverage.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
fail=0
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got '$3', want '$2'"; fail=1; fi; }
# A plugin with two skills, alpha and beta, and an eval case for each of the names given.
plugin() {
  local p="$dir/$1"; shift
  mkdir -p "$p/.claude-plugin" "$p/skills/engineering/alpha" "$p/skills/productivity/beta"
  echo '{"name":"p","skills":["./skills/engineering/alpha","./skills/productivity/beta"]}' > "$p/.claude-plugin/plugin.json"
  for s in "$@"; do
    mkdir -p "$p/evals/$s/first/graders"
    printf -- '---\nmax_turns: 3\n---\nhello\n' > "$p/evals/$s/first/prompt.md"
    printf -- '---\ntype: regex\npattern: hi\n---\n' > "$p/evals/$s/first/graders/word.md"
  done
  echo "$p"
}
run() { local out; out=$(bash "$check_cmd" "$1" 2>&1); echo "exit $? $out"; }

# Given a skill folder with no eval case under evals/
# When I run the tests
# Then the test fails and names the skill
out=$(run "$(plugin missing alpha)")
case "$out" in "exit 1"*beta*) echo "ok   S2-1 a skill with no case fails and is named" ;; *) echo "FAIL S2-1 a skill with no case fails and is named: got '$out'"; fail=1 ;; esac

# Given every skill has at least one eval case
# When I run the tests
# Then the coverage test passes
out=$(run "$(plugin full alpha beta)")
case "$out" in "exit 0"*) echo "ok   S2-2 full coverage passes" ;; *) echo "FAIL S2-2 full coverage passes: got '$out'"; fail=1 ;; esac

# Given a case with no grader
# When I run the tests
# Then the test fails and names the case, since the eval tool refuses to load it
p=$(plugin nograder alpha beta)
rm "$p/evals/beta/first/graders/word.md"
out=$(run "$p")
case "$out" in "exit 1"*beta/first*) echo "ok   S2-3 a case with no grader fails and is named" ;; *) echo "FAIL S2-3 a case with no grader fails and is named: got '$out'"; fail=1 ;; esac

exit $fail
