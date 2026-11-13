#!/usr/bin/env bash
# approved-spec: hooks judge one command at a time, approved 2026-11-13.
# G1 Given a branch with unmerged work, When one call restores a file and then runs `python3 -c`, Then git-guard lets it through.
# G2 Given the same branch, When a later command in the call makes a branch with -b, Then git-guard still refuses.
# R1 Given a new approved test and other changes in the tree, When one call holds two commits, Then red-first-guard refuses and says one commit per call.
# R2 Given the same tree, When one call stages only the test by name and commits, Then red-first-guard lets it through.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"; s="$root/plugins/vicky-skills/scripts"
d=$(mktemp -d); trap 'rm -rf "$d"' EXIT; fail=0
g() { git -C "$d/r" -c user.email=t@t -c user.name=t -c commit.gpgsign=false "$@"; }
git init -q -b main "$d/r"; g commit -q --allow-empty -m base; g switch -q -c work; g commit -q --allow-empty -m unmerged
run() { jq -n --arg c "$2" --arg d "$d/r" '{tool_name:"Bash",tool_input:{command:$c},cwd:$d}' |
  CLAUDE_PLUGIN_OPTION_GUARD_RED_FIRST=true bash "$s/$1" 2>"$d/err" >/dev/null; echo $?; }
expect() { if [ "$3" = "$2" ]; then echo "ok   $1"; else echo "FAIL $1: got $3, want $2"; fail=1; fi; }
expect "G1 a restore then python3 -c passes git-guard" 0 "$(run git-guard.sh 'git checkout -q -- f; python3 -c "print(1)"')"
expect "G2 a later checkout -b is still refused" 2 "$(run git-guard.sh 'true; git checkout -b topic')"
mkdir -p "$d/r/tests"; echo 'exit 1' > "$d/r/tests/x_approved_examples.test.sh"; echo code > "$d/r/code.sh"
expect "R1 two commits in one call are refused" 2 "$(run red-first-guard.sh 'git add tests/x_approved_examples.test.sh && git commit -m t && git add -A && git commit -m c')"
expect "R1 the refusal says one commit per call" 1 "$(grep -c 'one commit per call' "$d/err")"
expect "R2 staging only the test by name passes" 0 "$(run red-first-guard.sh 'git add tests/x_approved_examples.test.sh && git commit -m t')"
exit $fail
