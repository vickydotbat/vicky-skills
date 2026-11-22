#!/usr/bin/env bash
# The hook refuses a commit that adds a machine path, and only when switched on.
set -u
hook="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/local-path-guard.sh"
scratch=$(mktemp -d); trap 'rm -rf "$scratch"' EXIT
fail=0
export USER=pathtester HOME="$scratch/fakehome"
repo="$scratch/repo"
git init -q -b main "$repo"
g() { git -C "$repo" -c user.email=t@t -c user.name=t -c commit.gpgsign=false "$@"; }
g commit -q --allow-empty -m init
g remote add origin git@example.com:acme/widgets.git

# want exit, label, command; the hook runs with the option set in $opt.
opt=true
expect() {
  local want=$1 label=$2 cmd=$3 got
  got=$(jq -n --arg c "$cmd" --arg d "$repo" '{cwd:$d,tool_input:{command:$c}}' |
    CLAUDE_PLUGIN_OPTION_GUARD_LOCAL_PATHS=$opt "$hook" >/dev/null 2>&1; echo $?)
  if [ "$got" = "$want" ]; then echo "ok   $label"; else echo "FAIL $label: want $want, got $got"; fail=1; fi
}
stage() { printf '%s\n' "$1" >"$repo/pathfile"; g add pathfile; }
unstage() { g rm -q --cached -f pathfile; rm -f "$repo/pathfile"; }
commit='git commit -m "add config"'

stage 'config at /home/someone/.config/x';   expect 2 "refuses /home/<name>/" "$commit"
opt=off;                                     expect 0 "option off passes" "$commit"
opt=1;                                       expect 2 "option 1 is on" "$commit"
opt=true; unstage
stage 'see /Users/someone/Library/x';        expect 2 "refuses /Users/<name>/" "$commit"; unstage
stage 'uses /nix/store/abc-foo/bin/foo';     expect 2 "refuses /nix/store/" "$commit"; unstage
stage "open $HOME/notes";                    expect 2 "refuses the home directory" "$commit"; unstage
stage "cd /srv/$USER/project";               expect 2 "refuses /<user>/ segment" "$commit"; unstage
stage "cd /data/x/$USER/project";            expect 2 "refuses /<user>/ deep in an absolute path" "$commit"; unstage
stage "imports ../../users/$USER/system.nix";  expect 0 "a repo-relative users/<user>/ folder passes" "$commit"; unstage
stage "see \`users/$USER/profiles/x.nix\`";    expect 0 "a repo path naming a user folder passes" "$commit"; unstage
stage "ssh $USER@somehost";                  expect 2 "refuses <user>@" "$commit"; unstage
stage "author ${USER}dotbat, plugin ${USER}-skills, ${USER} said hi"
                                             expect 0 "bare or longer user name passes" "$commit"; unstage
# The folder name is built at run time, because the guard installed when this
# test was written refused the literal.
h=home; stage "records=\"\$scratch/$h/.claude/x\"";  expect 0 "a home folder inside a variable's folder passes" "$commit"; unstage
u=Users; stage "see \${root}/$u/me/x and lib/$h/a/"; expect 0 "a home folder inside another folder passes" "$commit"; unstage
stage 'config at "/home/someone/.config/x"';  expect 2 "refuses a quoted /home/<name>/" "$commit"; unstage # local-path-ok
stage 'fixture /home/someone/x # local-path-ok'; expect 0 "a line marked local-path-ok passes" "$commit"; unstage # local-path-ok
stage 'relative docs/readme.md only';        expect 0 "clean line passes" "$commit"
expect 0 "not a commit passes" 'git status'
expect 0 "message mentioning commit is text" 'git log --grep="git commit"'
unstage

printf 'old /home/someone/x\n' >"$repo/pathfile"; g add pathfile; g commit -q -m add
g rm -q pathfile
expect 0 "removing a path is fine" 'git commit -m "drop it"'
g reset -q --hard

printf 'clean\n' >"$repo/tracked"; g add tracked; g commit -q -m tracked
printf 'see /home/someone/x\n' >>"$repo/tracked" # local-path-ok
expect 2 "a path in a tracked change the same command adds" 'git add -u && git commit -m add'
g reset -q --hard
printf 'see /home/someone/x\n' >"$repo/fresh"
expect 2 "path in a file the same command adds" 'git add -A && git commit -m add'
expect 0 "nothing staged passes" 'git status && git commit -m "nothing staged"'
CLAUDE_PLUGIN_OPTION_LOCAL_PATH_EXEMPT_REPOS="other/thing acme/widgets" \
  expect 0 "exempt repo passes" 'git add -A && git commit -m add'
CLAUDE_PLUGIN_OPTION_LOCAL_PATH_EXEMPT_REPOS="acme/widg" \
  expect 2 "part of a repo name exempts nothing" 'git add -A && git commit -m add'
rm "$repo/fresh"
printf 'bin\0 /home/someone/x\n' >"$repo/blob" # local-path-ok
expect 0 "a binary untracked file is not scanned" 'git add -A && git commit -m add'
rm "$repo/blob"

# A repo with thousands of untracked files (a workbench's renders) finishes
# well inside the hook's timeout. The old scan built one string from every
# file and passed 120 s on 6,315 of them.
mkdir "$repo/many"
for i in $(seq 3000); do printf 'line %s\n' "$i" >"$repo/many/f$i.txt"; done
start=$SECONDS
expect 0 "thousands of clean untracked files pass" 'git add -A && git commit -m add'
took=$((SECONDS - start))
if [ "$took" -le 5 ]; then echo "ok   thousands of untracked files scan in ${took}s"
else echo "FAIL thousands of untracked files took ${took}s, over 5"; fail=1; fi
printf 'see /home/someone/x\n' >"$repo/many/f1500.txt" # local-path-ok
expect 2 "a path in one of thousands of untracked files is refused" 'git add -A && git commit -m add'
rm -r "$repo/many"

printf 'see /home/someone/x\n' >"$repo/local-path-ok.txt" # local-path-ok
expect 2 "a file named for the marker is still scanned" 'git add -A && git commit -m add'
rm "$repo/local-path-ok.txt"
printf 'fixture /home/someone/x # local-path-ok\n' >"$repo/marked.txt" # local-path-ok
expect 0 "a marked line in an untracked file passes" 'git add -A && git commit -m add'
rm "$repo/marked.txt"
printf 'ignored.txt\n' >"$repo/.gitignore"
printf 'see /home/someone/x\n' >"$repo/ignored.txt" # local-path-ok
expect 0 "an ignored file is not scanned" 'git add -A && git commit -m add'
rm "$repo/ignored.txt" "$repo/.gitignore"
exit $fail
