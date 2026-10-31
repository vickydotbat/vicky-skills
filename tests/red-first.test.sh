#!/usr/bin/env bash
# The red-first check's and commit guard's decisions the approved examples
# leave out: usage errors, the count it reports, staging in the commit
# command, and a commit that adds a new file that is no approved test.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
scripts="$root/plugins/vicky-skills/scripts"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
fail=0
expect() { # name want got
  if [ "$3" = "$2" ]; then echo "ok   $1"; else echo "FAIL $1: got '$3', want '$2'"; fail=1; fi
}
commit() { git -C "$repo" -c user.name=t -c user.email=t@example.invalid commit -q -m "$1"; }
repo="$dir/repo"; git init -q -b main "$repo"; git -C "$repo" commit -q --allow-empty -m base -c user.name=t 2>/dev/null ||
  git -C "$repo" -c user.name=t -c user.email=t@example.invalid commit -q --allow-empty -m base
check() { (cd "${2:-$repo}" && bash "$scripts/red-first-check.sh" $1 >"$dir/out" 2>&1); echo $?; }

expect "the check with no base is a usage error" 2 "$(check "")"
expect "the check outside a repository is an error" 2 "$(check main "$dir")"
git -C "$repo" switch -q -c work
mkdir -p "$repo/tests"
printf 'exit 1\n' > "$repo/tests/a_approved_examples.test.sh"; git -C "$repo" add .; commit a
printf 'exit 1\n' > "$repo/tests/b_approved_examples.test.sh"; git -C "$repo" add .; commit b
expect "a branch whose approved tests were red passes" 0 "$(check main)"
expect "  and its report counts them" "red-first: 2 approved tests, each red at the commit that added it." "$(cat "$dir/out")"
printf 'exit 0\n' > "$repo/tests/c_approved_examples.test.sh"; git -C "$repo" add .; commit c
expect "a test that passed where it landed fails the check" 1 "$(check main)"
expect "  and no all-red report is printed" 0 "$(grep -c 'each red' "$dir/out")"
expect "a run command takes the test's path" 0 "$(check "main HEAD --run 'test {} != tests/c_approved_examples.test.sh && exit 0; exit 1'")"

guard() { jq -n --arg c "$1" --arg d "$repo" '{tool_name: "Bash", tool_input: {command: $c}, cwd: $d}' |
  CLAUDE_PLUGIN_OPTION_GUARD_RED_FIRST=true bash "$scripts/red-first-guard.sh" >/dev/null 2>&1; echo $?; }
printf 'exit 1\n' > "$repo/tests/d_approved_examples.test.sh"; printf 'code\n' > "$repo/new.sh"
expect "a commit that stages a new approved test with code itself is refused" 2 "$(guard 'git add -A && git commit -m both')"
rm "$repo/tests/d_approved_examples.test.sh"
expect "a commit of a new file that is no approved test runs" 0 "$(guard 'git add -A && git commit -m code')"
printf 'exit 1\n' > "$repo/tests/e_approved_examples.test.sh"; git -C "$repo" add -A
expect "a git command that is no commit runs, with a new approved test and code staged" 0 "$(guard 'git status')"
exit $fail
