#!/usr/bin/env bash
# A test or hook script that calls a runtime must find it named in tests/tools,
# so "works on my machine" never needs saying: tools-present.sh then checks it
# is installed before the tests run, here and in CI.
set -u
root=$(cd "$(dirname "$0")/.." && pwd)
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
# Runtimes a script might reach for. One not in tests/tools and called from a
# script is undeclared.
runtimes="node npx npm deno bun ruby perl go cargo php lua docker podman chromium playwright tmux shellcheck yq mmdc"
undeclared() { # $1: tools file, rest: scripts
  local tools=$1; shift
  for r in $runtimes; do
    grep -qx "$r" "$tools" && continue
    # A call sits at command position: a line's start, after $(, a pipe, && or ;,
    # or after if, then, do, else or !.
    grep -lE "(^[[:space:]]*|\\\$\(|[|;&][[:space:]]*|(if|then|do|else|!)[[:space:]]+)$r([[:space:]]|$)" "$@" 2>/dev/null | sed "s|^|$r: |"
  done
}
# This file is left out: its fixtures hold the calls it looks for.
shopt -s globstar
scripts=()
for f in "$root"/tests/*.sh "$root"/plugins/**/*.sh; do [ "${f##*/}" = tools-declared.test.sh ] || scripts+=("$f"); done
found=$(undeclared "$root/tests/tools" "${scripts[@]}")
check "every runtime a test or hook script calls is named in tests/tools" '[ -z "$found" ] || { echo "$found  -> add it to tests/tools"; false; }'

scratch=$(mktemp -d); trap 'rm -rf "$scratch"' EXIT
printf 'x=$(node - <<JS\nJS\n)\n' >"$scratch/a.test.sh"
printf 'jq\n' >"$scratch/tools"
check "a script that calls node with node missing from tests/tools is caught" '[ "$(undeclared "$scratch/tools" "$scratch/a.test.sh")" = "node: $scratch/a.test.sh" ]'
for form in 'if node -v; then :; fi' '! node -v' 'true && node -v' 'for x in 1; do node -v; done'; do
  printf '%s\n' "$form" >"$scratch/c.test.sh"
  check "node called as \"$form\" is caught" '[ -n "$(undeclared "$scratch/tools" "$scratch/c.test.sh")" ]'
done
printf 'jq\nnode\n' >"$scratch/tools"
check "the same script passes once node is declared" '[ -z "$(undeclared "$scratch/tools" "$scratch/a.test.sh")" ]'
printf 'echo "a node of the chart"\n' >"$scratch/b.test.sh"
printf 'jq\n' >"$scratch/tools"
check "the word node in prose is not a call" '[ -z "$(undeclared "$scratch/tools" "$scratch/b.test.sh")" ]'
printf 'jq\nno-such-tool-here\n' >"$scratch/tools"
check "tools-present.sh names a declared tool this machine lacks" '! "$root/tests/tools-present.sh" "$scratch/tools" 2>"$scratch/err" && grep -q "missing tool: no-such-tool-here" "$scratch/err" && ! grep -q "missing tool: jq" "$scratch/err"'
check "tools-present.sh passes when every tool is here" '"$root/tests/tools-present.sh"'
exit $fail
