#!/usr/bin/env bash
# The shellcheck guard's decisions beyond its approved examples: which pushes it
# reads, which files count as shell, and every way it stays out of the way.
set -u
hook="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/shellcheck-guard.sh"
scratch=$(mktemp -d); trap 'rm -rf "$scratch"' EXIT
fail=0
gi() { git -C "$1" -c user.email=t@t -c user.name=t -c commit.gpgsign=false "${@:2}"; }
expect() { # want label dir command [env]
  local got
  got=$(jq -n --arg c "$4" --arg d "$3" '{cwd:$d,tool_input:{command:$c}}' | env "${5:-X=1}" "$hook" >/dev/null 2>&1; echo $?)
  if [ "$got" = "$1" ]; then echo "ok   $2"; else echo "FAIL $2: want $1, got $got"; fail=1; fi
}
w="$scratch/w"; rem="$scratch/rem"
git init -q --bare -b main "$rem"; git clone -q "$rem" "$w" 2>/dev/null
gi "$w" checkout -q -b main 2>/dev/null; gi "$w" commit -q --allow-empty -m one; gi "$w" push -q origin main
gi "$w" remote set-head origin main; gi "$w" checkout -q -b topic
# shellcheck disable=SC2016 # the script under test is written out literally
printf '#!/bin/sh\nc=$1\nls $c\n' >"$w/tool"
gi "$w" add -A; gi "$w" commit -q -m tool

expect 2 "a script named by its shebang alone counts" "$w" "git push origin topic"
expect 2 "a bare push is read" "$w" "git push"
expect 2 "a push aimed by cd is read" "$scratch" "cd $w && git push origin topic"
expect 0 "a deleting push passes" "$w" "git push origin --delete topic"
expect 0 "another git command passes" "$w" "git status"
expect 0 "a push named only in quoted text passes" "$w" "echo 'git push'"
expect 0 "the setting off passes" "$w" "git push" CLAUDE_PLUGIN_OPTION_GUARD_SHELLCHECK=false
expect 0 "the setting 0 passes" "$w" "git push" CLAUDE_PLUGIN_OPTION_GUARD_SHELLCHECK=0
printf 'Shellcheck: off\n' >"$w/AGENTS.md"
expect 0 "Shellcheck: off in AGENTS.md passes" "$w" "git push"
rm "$w/AGENTS.md"
printf 'disable=SC2086\n' >"$w/.shellcheckrc"
expect 0 "the repo's .shellcheckrc is read" "$w" "git push"
rm "$w/.shellcheckrc"
nosc="$scratch/nosc"; mkdir "$nosc"
for t in bash jq git grep sed awk cat head timeout dirname env tr; do ln -s "$(command -v $t)" "$nosc/$t"; done
expect 0 "a missing shellcheck passes" "$w" "git push" "PATH=$nosc"
g2="$scratch/g2"; git init -q "$g2"; gi "$g2" commit -q --allow-empty -m one
expect 0 "a repo with no origin passes" "$g2" "git push"
got=$(echo "not json" | "$hook" >/dev/null 2>&1; echo $?)
if [ "$got" = 0 ]; then echo "ok   bad input passes"; else echo "FAIL bad input passes: got $got"; fail=1; fi
exit $fail
