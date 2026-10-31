#!/usr/bin/env bash
# The commit guard reads what `git add <files> && git commit` stages: only the
# files it names, so an unrelated change left unstaged never counts. A flag,
# a folder or a glob stages more, and then every change counts.
set -u
scripts="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts"
dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
fail=0
expect() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got $3, want $2"; fail=1; fi; }
repo="$dir/repo"
git init -q -b main "$repo"
mkdir -p "$repo/tests"
printf 'old\n' >"$repo/ci.yml"
git -C "$repo" add .
git -C "$repo" -c user.name=t -c user.email=t@example.invalid commit -q -m base
guard() { jq -n --arg c "$1" --arg d "$repo" '{tool_name: "Bash", tool_input: {command: $c}, cwd: $d}' |
  CLAUDE_PLUGIN_OPTION_GUARD_RED_FIRST=true bash "$scripts/red-first-guard.sh" >/dev/null 2>&1; echo $?; }

t=tests/f_appro"ved"_examples.test.sh
printf 'exit 1\n' >"$repo/$t"
printf 'new\n' >"$repo/ci.yml"
expect "git add of the test alone runs, with another file changed and unstaged" 0 "$(guard "git add $t && git commit -m red")"
expect "git add of the test and the changed file is refused" 2 "$(guard "git add $t ci.yml && git commit -m both")"
expect "git add of a folder counts every change" 2 "$(guard "git add tests/ && git commit -m red")"
expect "git add of . counts every change" 2 "$(guard "git add . && git commit -m red")"
expect "git add -u counts every change" 2 "$(guard "git add -u && git commit -m red")"
expect "git add of a glob counts every change" 2 "$(guard "git add tests/*.sh && git commit -m red")"
expect "git add of a path that isn't a file counts every change" 2 "$(guard "git add gone.sh $t && git commit -m red")"
git -C "$repo" add ci.yml
expect "what is already staged still counts" 2 "$(guard "git add $t && git commit -m red")"
git -C "$repo" restore --staged ci.yml
expect "commit -a counts every change" 2 "$(guard "git add $t && git commit -am red")"
exit $fail
