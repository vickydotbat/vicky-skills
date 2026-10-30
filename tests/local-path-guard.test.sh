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
stage "ssh $USER@somehost";                  expect 2 "refuses <user>@" "$commit"; unstage
stage "author ${USER}dotbat, plugin ${USER}-skills, ${USER} said hi"
                                             expect 0 "bare or longer user name passes" "$commit"; unstage
stage 'relative docs/readme.md only';        expect 0 "clean line passes" "$commit"
expect 0 "not a commit passes" 'git status'
expect 0 "message mentioning commit is text" 'git log --grep="git commit"'
unstage

printf 'old /home/someone/x\n' >"$repo/pathfile"; g add pathfile; g commit -q -m add
g rm -q pathfile
expect 0 "removing a path is fine" 'git commit -m "drop it"'
g reset -q --hard

printf 'see /home/someone/x\n' >"$repo/fresh"
expect 2 "path in a file the same command adds" 'git add -A && git commit -m add'
expect 0 "nothing staged passes" 'git status && git commit -m "nothing staged"'
CLAUDE_PLUGIN_OPTION_LOCAL_PATH_EXEMPT_REPOS="other/thing acme/widgets" \
  expect 0 "exempt repo passes" 'git add -A && git commit -m add'
CLAUDE_PLUGIN_OPTION_LOCAL_PATH_EXEMPT_REPOS="acme/widg" \
  expect 2 "part of a repo name exempts nothing" 'git add -A && git commit -m add'
rm "$repo/fresh"
printf 'bin\0/home/someone/x\n' >"$repo/blob"
expect 0 "a binary untracked file is not scanned" 'git add -A && git commit -m add'
rm "$repo/blob"
exit $fail
