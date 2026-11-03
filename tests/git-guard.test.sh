#!/usr/bin/env bash
# What git-guard must and must not stop, driven the way Claude Code drives it: a
# JSON payload on stdin, and an exit status. 0 means allowed, 2 means refused.
#
#   bash tests/git-guard.test.sh
#
# Ported with the guard from the NixOS config, where it ran against the installed hook.
# Covers branch switches, which pass anywhere, plus rules 1, 2 and 4.
set -euo pipefail

hook="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/git-guard.sh"
export CLAUDE_PLUGIN_OPTION_GUARD_GIT=true CLAUDE_PLUGIN_OPTION_GIT_GUARD_TRUNK_REPOS=vickydotbat/nixos,nwncxee/cx.wiki
[[ -f "$hook" ]] || { echo "git-guard-test: no hook at $hook" >&2; exit 1; }

scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT

# A main checkout with a merged feature branch, and a linked worktree of it.
git init -q -b main "$scratch/repo"
g() { git -C "$scratch/repo" -c user.email=t@t -c user.name=t -c commit.gpgsign=false "$@"; }
g commit -q --allow-empty -m init
g branch feature
echo x >"$scratch/repo/file"
g worktree add -q "$scratch/wt" feature

failed=0
expect() {
  local want=$1 cwd=$2 command=$3 got
  got=$(printf '{"tool_name":"Bash","cwd":"%s","tool_input":{"command":%s}}' "$cwd" "$(printf '%s' "$command" | jq -Rs .)" |
    bash "$hook" >/dev/null 2>&1 && echo 0 || echo $?)
  [[ $got == "$want" ]] || { echo "FAIL want $want, got $got: ($cwd) $command"; failed=1; }
}

main="$scratch/repo"
wt="$scratch/wt"

# The main checkout: a switch to a branch or a commit, new or old, passes.
expect 0 "$main" 'git checkout feature'
expect 0 "$main" 'git switch feature'
expect 0 "$main" 'git checkout -b topic'
expect 0 "$main" 'git switch -c topic'
expect 0 "$main" "git checkout $(g rev-parse HEAD)"
expect 0 "$scratch" "git -C $main switch feature"
expect 0 "$main" 'git checkout -- file'
expect 0 "$main" 'git status'

# A linked worktree switches the same way.
expect 0 "$wt" 'git switch main'
expect 0 "$wt" 'git checkout feature'

# Rule 1: no new branch from a branch that main has not merged.
git -C "$wt" -c user.email=t@t -c user.name=t -c commit.gpgsign=false commit -q --allow-empty -m unmerged
expect 2 "$wt" 'git checkout -b topic'
expect 2 "$wt" 'git switch -c topic'
expect 2 "$wt" 'git switch -c topic feature'
expect 2 "$wt" 'git switch -c mainline-fix'
# Starting from main is the rule's own advice, so it passes.
expect 0 "$wt" 'git switch -c topic origin/main'
expect 0 "$wt" 'git worktree add -q -b topic ../wt4 origin/main'
expect 2 "$wt" 'git worktree add -q -b topic ../wt4'
expect 0 "$wt" 'git fetch origin && git switch -c topic main'
expect 0 "$wt" 'git checkout -b topic origin/main && git status'
# A redirect or pipe after the base is still a branch from main.
expect 0 "$wt" 'git worktree add -q -b topic ../wt4 origin/main 2>&1 | tail -1'
expect 0 "$wt" 'git worktree add -q -b topic ../wt4 origin/main >/dev/null'
expect 2 "$wt" 'git worktree add -q -b topic ../wt4 origin/mainline'
# A branch whose remote is gone was squash-merged: branching on passes.
git -C "$wt" config branch.feature.remote origin
git -C "$wt" config branch.feature.merge refs/heads/feature
git -C "$wt" remote add origin "$scratch/nowhere" 2>/dev/null || true
git -C "$wt" update-ref refs/remotes/origin/main HEAD
expect 0 "$wt" 'git switch -c topic'
git -C "$wt" config --unset branch.feature.remote
git -C "$wt" config --unset branch.feature.merge
git -C "$wt" remote remove origin

# Rule 2: no push to main.
expect 2 "$main" 'git push origin main'
expect 0 "$wt" 'git push -u origin feature'

# Rule 4: no commit that sets its own identity.
expect 2 "$main" 'git commit --author="x <x@example.com>" -m msg'
expect 2 "$main" 'git -c user.email=x@example.com commit -m msg'
expect 2 "$main" 'GIT_AUTHOR_EMAIL=x@example.com git commit -m msg'
expect 2 "$main" 'GIT_COMMITTER_EMAIL=x@example.com git commit-tree HEAD^{tree} -m msg'
expect 0 "$main" 'git commit -m msg'

# A trunk repository takes pushes to main, also when the command reaches it
# through a leading cd and goes on to a second repository.
git init -q -b main "$scratch/trunk"
git -C "$scratch/trunk" remote add origin git@github.com:vickydotbat/nixos.git
trunk="$scratch/trunk"
expect 0 "$trunk" 'git push origin main'
expect 0 "$scratch" "cd $trunk && git push -q origin main"
expect 0 "$scratch" "cd $trunk && git status -sb | head -1 && git push -q origin main && git status -sb | head -1; cd $main && git status"
expect 2 "$trunk" 'git switch -c topic'
expect 2 "$trunk" 'git worktree add -q -b topic ../wt2 origin/main'
expect 2 "$scratch" "cd $trunk; git fetch -q; git worktree add -q -b topic ../wt2 origin/main"
expect 0 "$trunk" 'git worktree add -q ../wt3 main'
# Text that mentions a branch switch is not a branch switch.
expect 0 "$trunk" 'git commit -q -m "agents now run git switch -c topic origin/main"'
expect 0 "$trunk" $'git commit -q -F - <<\'EOF\'\nfix: git switch -c used to be refused\nEOF'
expect 0 "$trunk" $'cat > /dev/null <<EOF\ngit checkout -b x\nEOF\ngit status'
expect 2 "$trunk" $'cat > /dev/null <<EOF\nnote\nEOF\ngit switch -c topic'
# The credit rule still reads the message, heredoc included.
expect 2 "$trunk" $'git commit -q -F - <<\'EOF\'\nfix\n\nCo-Authored-By: Claude <noreply@anthropic.com>\nEOF'
# Claude Code strips a leading `cd <cwd> &&`, so a later cd is all the hook
# sees. It moves the shell after the push and must not decide the push's repo.
expect 0 "$trunk" "git push -q origin main; cd $main && git status"
expect 2 "$main" "git push -q origin main; cd $trunk && git status"

# A GitHub wiki keeps one branch, so its push to master passes; the code
# repository whose name it extends is still refused.
git init -q -b master "$scratch/wiki"
git -C "$scratch/wiki" remote add origin git@github.com:nwncxee/cx.wiki.git
expect 0 "$scratch/wiki" 'git push origin master'
git init -q -b master "$scratch/code"
git -C "$scratch/code" remote add origin git@github.com:nwncxee/cx.git
expect 2 "$scratch/code" 'git push origin master'

# A bare push, or a push of HEAD, from main lands on main.
expect 2 "$scratch/code" 'git push origin'
expect 2 "$scratch/code" 'git push origin HEAD'
# A word after push in another command is no push.
expect 0 "$scratch/code" 'git status && echo push origin master'
# With no main or master there is nothing to compare, so a new branch runs.
git init -q -b trunkless "$scratch/bare"
git -C "$scratch/bare" -c user.email=t@t -c user.name=t -c commit.gpgsign=false commit -q --allow-empty -m one
git -C "$scratch/bare" switch -q -c topic2
git -C "$scratch/bare" -c user.email=t@t -c user.name=t -c commit.gpgsign=false commit -q --allow-empty -m two
expect 0 "$scratch/bare" 'git switch -c topic3'
# With both main and master, main is the base: a branch merged into main runs.
git init -q -b main "$scratch/both"
git -C "$scratch/both" -c user.email=t@t -c user.name=t -c commit.gpgsign=false commit -q --allow-empty -m one
git -C "$scratch/both" branch master
git -C "$scratch/both" switch -q -c done
git -C "$scratch/both" -c user.email=t@t -c user.name=t -c commit.gpgsign=false commit -q --allow-empty -m two
git -C "$scratch/both" switch -q main && git -C "$scratch/both" merge -q --ff-only done && git -C "$scratch/both" switch -q done
expect 0 "$scratch/both" 'git switch -c next'

if [[ $failed -eq 0 ]]; then echo "git-guard-test: all cases pass"; fi
exit "$failed"
