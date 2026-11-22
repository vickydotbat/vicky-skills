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
git init -q -b main "$scratch/forge"; git -C "$scratch/forge" remote add origin git@forge.example.org:team/app.git
printf 'See forge.example.org/team/app\n' > "$scratch/forge/host.md"
printf '# #1641 Other\n' > "$scratch/other.md"
rin() { jq -n --arg c "$1" --arg d "$scratch/$2" '{cwd:$d,tool_input:{command:$c}}' | "$hook" >/dev/null 2>"$scratch/err"; echo $?; }
expect 0 "$(rin "gh pr edit 3 -R forge.example.org/team/app --body-file host.md" forge)" "gh posting to its own forge by full repo name passes"
expect 2 "$(rin "cd forge && gh pr edit 3 -R acme/widgets --body-file host.md" .)" "a cd moves the checkout and the body file with it"
expect 2 "$(rin "cd forge
gh pr edit 3 -R acme/widgets --body-file host.md" .)" "a cd on its own line moves the checkout too"
expect 2 "$(rin "gh pr edit --unknown 306 -F $scratch/other.md" r)" "a boolean flag before the number leaves the number read"
printf '# #306 Own\n' > "$scratch/own306.md"
expect 0 "$(rin "gh pr edit -t 1641 306 -F $scratch/own306.md" r)" "a title value is never read as the number"
printf '# #3 Own\n' > "$scratch/own.md"
expect 2 "$(rin "tea pr edit --repo team/app 1641 --description-file $scratch/own.md" forge)" "tea reads the number after a repo value"
expect 2 "$(run "tea pr edit 3 --description-file $scratch/leak.md" )" "a missing tea description file is refused"
printf 'Built /%s/x\n' "$ns" > "$scratch/leak.md"
expect 2 "$(rin "tea pr edit 3 --description-file $scratch/leak.md" forge)" "a leaking tea description file is refused"
expect 2 "$(rin "tea comment 3 -d '/$ns/x'" forge)" "tea comment -d with a leak is refused"
expect 2 "$(run "gh pr comment 3 --body hi,/$ns/x")" "an unquoted body is read whole"
expect 2 "$(run "gh pr edit 3 --body")" "a body flag with no value is refused"
expect 0 "$(run 'gh api repos/acme/widgets/issues/3 -f title=hi')" "gh api with only other fields passes"
expect 2 "$(run 'gh api repos/acme/widgets/issues/3/comments --raw-field=body=hi')" "gh api --raw-field=body= is refused"
expect 0 "$(run 'echo api -f body=x')" "the word api without gh is no post"
expect 0 "$(run 'command -v gh')" "gh as the last word is no post"
expect 0 "$(run 'echo comment x; command -v tea')" "tea as the last word is no post"
expect 0 "$(run "echo \"gh 'x")" "a broken command that names gh and is no post passes"
expect 2 "$(run "gh pr edit 3 --body '/$ns/x'")" "a leak gets the refusal header"
grep -qF 'post-body-guard: refused' "$scratch/err" && grep -qF 'Rewrite the body by role' "$scratch/err" && echo "ok   the refusal says what to do" || { echo "FAIL the refusal says what to do"; fail=1; }
expect 2 "$(run "gh pr edit 3 --body 'x")" "a post with broken quoting is refused"; grep -qF -- '--body-file' "$scratch/err" && echo "ok   a quoting refusal steers to --body-file" || { echo "FAIL a quoting refusal steers to --body-file"; fail=1; }
mkdir -p "$scratch/nogit"; for t in bash cat jq env python3; do ln -s "$(command -v $t)" "$scratch/nogit/$t"; done
expect 0 "$(run "gh pr comment 3 --body hi" PATH="$scratch/nogit")" "without git a clean post still passes"
out=$(printf 'not json' | "$hook" 2>&1); rc=$?
expect 0 "$rc" "bad input passes without a traceback"
exit $fail
