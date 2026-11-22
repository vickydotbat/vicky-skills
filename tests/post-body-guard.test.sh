#!/usr/bin/env bash
# post-body-guard.sh: the decisions the approved examples leave out: a missing
# python3, bad input, a command that is no post, gh api --input, and the
# setting off in the shell wrapper itself.
set -u
root=$(cd "$(dirname "$0")/.." && pwd)
hook="$root/plugins/vicky-skills/scripts/post-body-guard.sh"
scratch=$(mktemp -d); trap 'rm -rf "$scratch"' EXIT
fail=0
git init -q -b main "$scratch/r"; git -C "$scratch/r" remote add origin git@github.com:acme/widgets.git
run() { jq -n --arg c "$1" --arg d "$scratch/r" '{cwd:$d,tool_input:{command:$c}}' | env "${@:2}" "$hook" >/dev/null 2>"$scratch/err"; echo $?; }
expect() { if [ "$1" = "$2" ]; then echo "ok   $3"; else echo "FAIL $3: want $1, got $2: $(head -2 "$scratch/err")"; fail=1; fi; }
ns=nix/store
expect 0 "$(run 'ls -la')" "a command with no gh or tea passes"
expect 0 "$(run 'git log --oneline')" "git passes"
expect 0 "$(run 'gh pr list --state all')" "gh pr list is no post"
expect 2 "$(run 'gh api repos/acme/widgets/issues/3/comments --input body.json')" "gh api --input is refused"
expect 0 "$(run 'gh api repos/acme/widgets/pulls/3')" "gh api with no body passes"
expect 2 "$(run "tea issues create -t t -d '/$ns/x'")" "tea issues create with a leak is refused"
expect 2 "$(run "gh pr edit 3 --body 'unterminated")" "a post whose quoting does not parse is refused"
expect 0 "$(run "echo 'unterminated")" "a broken command that is no post passes"
expect 0 "$(run "gh pr edit 3 --body '/$ns/x'" CLAUDE_PLUGIN_OPTION_GUARD_POST_BODY=false)" "the setting off passes in the wrapper"
mkdir -p "$scratch/bin"; for t in bash cat grep jq env; do ln -s "$(command -v $t)" "$scratch/bin/$t"; done
expect 2 "$(run "gh pr edit 3 --body hi" PATH="$scratch/bin")" "without python3 a post is refused"
grep -qF python3 "$scratch/err" && echo "ok   the refusal names python3" || { echo "FAIL the refusal names python3"; fail=1; }
expect 0 "$(run "ls" PATH="$scratch/bin")" "without python3 a command that is no post passes"
out=$(printf 'not json' | "$hook" 2>&1); rc=$?
expect 0 "$rc" "bad input passes without a traceback"
exit $fail
