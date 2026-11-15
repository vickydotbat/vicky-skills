#!/usr/bin/env bash
# The commit guard asks git what `git add <args> && git commit` stages, so a
# folder, a glob or a flag counts exactly the changes it takes, and an
# unrelated change left unstaged never counts.
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
expect "git add of a folder that holds only the test runs" 0 "$(guard "git add tests/ && git commit -m red")"
printf 'code\n' >"$repo/tests/helper.sh"
expect "git add of a folder that also holds code is refused" 2 "$(guard "git add tests/ && git commit -m red")"
rm "$repo/tests/helper.sh"
expect "git add of . takes every change" 2 "$(guard "git add . && git commit -m red")"
expect "git add -u leaves the untracked test out, so the commit holds no new test" 0 "$(guard "git add -u && git commit -m red")"
expect "git add of a glob that matches only the test runs" 0 "$(guard "git add tests/*.sh && git commit -m red")"
expect "git add of a glob that matches code too is refused" 2 "$(guard "git add *.yml tests/*.sh && git commit -m red")"
expect "git add of a path that isn't there stages nothing, as the real add fails" 0 "$(guard "git add gone.sh $t && git commit -m red")"
git -C "$repo" add ci.yml
expect "what is already staged still counts" 2 "$(guard "git add $t && git commit -m red")"
git -C "$repo" restore --staged ci.yml
expect "commit -a takes the changed tracked file" 2 "$(guard "git add $t && git commit -am red")"
git -C "$repo" restore ci.yml
expect "commit -a with nothing tracked changed takes only the test" 0 "$(guard "git add $t && git commit -am red")"
printf 'new\n' >"$repo/ci.yml"
expect "a quoted git add in a commit message stages nothing" 0 "$(guard "git add $t && git commit -m 'no git add . here'")"
exit $fail
