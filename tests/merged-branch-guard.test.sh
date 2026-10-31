#!/usr/bin/env bash
# The hook refuses a commit or push on a branch whose remote branch is gone,
# names the move, and only when switched on.
set -u
hook="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/merged-branch-guard.sh"
scratch=$(mktemp -d); trap 'rm -rf "$scratch"' EXIT
fail=0
opt=true
gi() { git -C "$1" -c user.email=t@t -c user.name=t -c commit.gpgsign=false "${@:2}"; }
expect() { # $1 want exit, $2 label, $3 cwd, $4 command, $5 text the refusal holds (optional)
  local got
  jq -n --arg c "$4" --arg d "$3" '{cwd:$d,tool_input:{command:$c}}' |
    CLAUDE_PLUGIN_OPTION_GUARD_MERGED_BRANCH=$opt "$hook" >/dev/null 2>"$scratch/err"; got=$?
  if [ "$got" != "$1" ]; then echo "FAIL $2: want $1, got $got"; fail=1; return; fi
  if [ -n "${5:-}" ] && ! grep -qF -- "$5" "$scratch/err"; then echo "FAIL $2: no '$5' in: $(cat "$scratch/err")"; fail=1; return; fi
  echo "ok   $2"
}
# A remote on $1 as default, a seed clone that merges, and a work clone on topic.
setup() {
  local dflt=$1
  rem="$scratch/rem-$dflt"; seed="$scratch/seed-$dflt"; w="$scratch/work-$dflt"
  git init -q --bare -b "$dflt" "$rem"
  git clone -q "$rem" "$seed" 2>/dev/null
  gi "$seed" checkout -q -b "$dflt" 2>/dev/null
  gi "$seed" commit -q --allow-empty -m one
  gi "$seed" push -q origin "$dflt"
  git clone -q "$rem" "$w" 2>/dev/null
  gi "$w" checkout -q -b topic
  echo a > "$w/a"; gi "$w" add a; gi "$w" commit -q -m topic-a
}
squash() { # squash-merge topic on the remote and delete it, as a forge does
  gi "$seed" fetch -q origin topic
  gi "$seed" merge -q --squash FETCH_HEAD >/dev/null; gi "$seed" commit -q -m "topic (#1)"
  gi "$seed" push -q origin "$1"; gi "$seed" push -q origin --delete topic 2>/dev/null
}

setup main
expect 0 "a branch never pushed passes" "$w" 'git commit -m x'
gi "$w" push -q -u origin topic 2>/dev/null
expect 0 "a live branch passes" "$w" 'git commit -m x'
squash main
# The work clone has not fetched: the hook asks origin itself.
expect 2 "gone on origin, before any fetch, is refused" "$w" 'git commit -m x' "git switch -c <new-branch> origin/main"
expect 2 "the refusal says nothing needs moving after a squash" "$w" 'git commit -m x' "nothing needs moving"
expect 2 "a push is refused" "$w" 'git push'
expect 2 "git -C reaches the repo" "$scratch" "git -C $w commit -m x"
expect 2 "cd reaches the repo" "$scratch" "cd $w && git commit -m x"
expect 2 "a commit after another command is refused" "$w" 'git add -A; git commit -m x'
expect 0 "a delete push passes" "$w" 'git push origin --delete topic'
expect 0 "a short delete push passes" "$w" 'git push -d origin topic'
expect 0 "a status passes" "$w" 'git status'
expect 0 "the switch away passes" "$w" 'git fetch --prune && git switch -c next origin/main'
expect 0 "git commit inside a message is text" "$w" 'git log --grep "git commit"'
expect 0 "a word ending in git is no git" "$w" 'legit commit'
opt=off; expect 0 "option off passes" "$w" 'git commit -m x'; opt=1
expect 2 "option 1 counts as on" "$w" 'git commit -m x'; opt=true
echo b > "$w/b"; gi "$w" add b; gi "$w" commit -q -m after-one
expect 2 "commits after the merge are listed with the pick range" "$w" 'git commit -m x' "git cherry-pick"
grep -q "after-one" "$scratch/err" && echo "ok   the listed commit is after-one" || { echo "FAIL after-one not listed"; fail=1; }
# Origin unreachable: the last fetch's record decides.
gi "$w" fetch -q --prune origin
gi "$w" remote set-url origin "$scratch/nowhere"
expect 2 "unreachable origin, recorded gone, is refused" "$w" 'git commit -m x'
gi "$w" checkout -q -b live origin/main 2>/dev/null
gi "$w" config branch.live.remote origin; gi "$w" config branch.live.merge refs/heads/main
expect 0 "unreachable origin, recorded live, passes" "$w" 'git commit -m x'
gi "$w" checkout -q --detach
expect 0 "a detached HEAD passes" "$w" 'git commit -m x'

# A master default, with no origin/HEAD, found by its name.
setup master
gi "$w" push -q -u origin topic 2>/dev/null
gi "$w" remote set-head origin -d 2>/dev/null
squash master
gi "$w" fetch -q origin master
expect 2 "a master default is named" "$w" 'git commit -m x' "origin/master"
# A merge that kept the branch's commits: everything is already in main.
setup trunk
gi "$w" push -q -u origin topic 2>/dev/null
gi "$seed" fetch -q origin topic; gi "$seed" merge -q --ff-only FETCH_HEAD
gi "$seed" push -q origin trunk; gi "$seed" push -q origin --delete topic 2>/dev/null
gi "$w" fetch -q origin trunk
expect 2 "a fast-forward merge holds every commit" "$w" 'git commit -m x' "already in origin/trunk"
# A merge point the trees can't find: the refusal says how to check.
setup odd
gi "$w" push -q -u origin topic 2>/dev/null
gi "$seed" commit -q --allow-empty -m unrelated; gi "$seed" push -q origin odd
gi "$seed" push -q origin --delete topic 2>/dev/null
gi "$w" fetch -q origin odd
expect 2 "an unknown merge point says how to check" "$w" 'git commit -m x' "merge point is unknown"

# No origin/HEAD, main or master: the refusal falls back to origin/main.
setup dev
gi "$w" push -q -u origin topic 2>/dev/null
gi "$w" remote set-head origin -d 2>/dev/null
gi "$seed" push -q origin --delete topic 2>/dev/null
expect 2 "an unknown default falls back to origin/main" "$w" 'git commit -m x' "git switch -c <new-branch> origin/main"

mkdir "$scratch/bin"; for t in bash cat git dirname; do ln -s "$(command -v $t)" "$scratch/bin/$t"; done
jq -n --arg c 'git commit -m x' --arg d "$w" '{cwd:$d,tool_input:{command:$c}}' > "$scratch/payload"
PATH="$scratch/bin" CLAUDE_PLUGIN_OPTION_GUARD_MERGED_BRANCH=true "$(command -v bash)" "$hook" <"$scratch/payload" >/dev/null 2>&1
[ $? = 0 ] && echo "ok   without jq it lets the command run" || { echo "FAIL without jq"; fail=1; }
expect 0 "input that is not JSON passes" "$w" ''
exit $fail
