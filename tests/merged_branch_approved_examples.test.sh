#!/usr/bin/env bash
# approved-spec: the examples approved for "merged branch: switch to main and
# move". Each check is named after its example. The guard runs on real
# repositories, merged the way GitHub squash-merges and deletes the branch.
set -u
hook="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/merged-branch-guard.sh"
scratch=$(mktemp -d); trap 'rm -rf "$scratch"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
gi() { git -C "$1" -c user.email=t@t -c user.name=t -c commit.gpgsign=false "${@:2}"; }
run() { # $1 option, $2 command; stderr lands in $scratch/err
  jq -n --arg c "$2" --arg d "$w" '{cwd:$d,tool_input:{command:$c}}' |
    CLAUDE_PLUGIN_OPTION_GUARD_MERGED_BRANCH=$1 "$hook" >/dev/null 2>"$scratch/err"; }

rem="$scratch/rem"; seed="$scratch/seed"; w="$scratch/work"
git init -q --bare -b main "$rem"
git clone -q "$rem" "$seed" 2>/dev/null
gi "$seed" checkout -q -b main 2>/dev/null
gi "$seed" commit -q --allow-empty -m one
gi "$seed" push -q origin main
git clone -q "$rem" "$w" 2>/dev/null
gi "$w" checkout -q -b topic
echo a > "$w/a"; gi "$w" add a; gi "$w" commit -q -m topic-a
gi "$w" push -q -u origin topic 2>/dev/null

run true 'git commit -m more'; code=$?
check "given my branch's remote branch still exists, when the agent commits, then the commit goes through" '[ $code = 0 ]'

# Squash-merge topic into main, then delete its remote branch.
gi "$seed" fetch -q origin topic
gi "$seed" merge -q --squash FETCH_HEAD >/dev/null; gi "$seed" commit -q -m "topic (#1)"
gi "$seed" push -q origin main; gi "$seed" push -q origin --delete topic 2>/dev/null
gi "$w" fetch -q --prune origin

run true 'git commit -m more'; c1=$?
run true 'git push'; c2=$?
check "given the merged-branch guard is on and my branch's pull request merged, so its remote branch is gone, when the agent commits or pushes on it, then the command is refused, and the refusal tells it to switch to a fresh branch from origin's main and carry on there" \
  '[ $c1 = 2 ] && [ $c2 = 2 ] && grep -q "git switch -c <new-branch> origin/main" "$scratch/err"'

run true 'git commit -m more'
check "given the merged branch holds no commit made after its merge, when the guard refuses, then the refusal says nothing needs moving" \
  'grep -q "nothing needs moving" "$scratch/err"'

echo b > "$w/b"; gi "$w" add b; gi "$w" commit -q -m after-one
echo c > "$w/c"; gi "$w" add c; gi "$w" commit -q -m after-two
run true 'git commit -m more'
check "given the merged branch holds two commits made after its merge, when the guard refuses, then the refusal lists those two commits to carry onto the new branch" \
  'grep -q "after-one" "$scratch/err" && grep -q "after-two" "$scratch/err" && ! grep -q "topic-a" "$scratch/err" && ! grep -q "nothing needs moving" "$scratch/err"'

run false 'git commit -m more'; code=$?
check "given the merged-branch guard is off, when the agent commits on a merged branch, then the commit goes through" '[ $code = 0 ]'
exit $fail
