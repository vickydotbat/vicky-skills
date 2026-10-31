#!/usr/bin/env bash
# The hook refuses a push of a branch behind origin's default, and only when switched on.
set -u
hook="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/push-behind-guard.sh"
scratch=$(mktemp -d); trap 'rm -rf "$scratch"' EXIT
fail=0
opt=true
expect() {
  local want=$1 label=$2 cwd=$3 cmd=$4 got
  got=$(jq -n --arg c "$cmd" --arg d "$cwd" '{cwd:$d,tool_input:{command:$c}}' |
    CLAUDE_PLUGIN_OPTION_GUARD_PUSH_BEHIND=$opt "$hook" >/dev/null 2>&1; echo $?)
  if [ "$got" = "$want" ]; then echo "ok   $label"; else echo "FAIL $label: want $want, got $got"; fail=1; fi
}
gi() { git -C "$1" -c user.email=t@t -c user.name=t -c commit.gpgsign=false "${@:2}"; }

for dflt in main master; do
  rem="$scratch/rem-$dflt"; seed="$scratch/seed-$dflt"; w="$scratch/work-$dflt"
  git init -q --bare -b "$dflt" "$rem"
  git clone -q "$rem" "$seed" 2>/dev/null
  gi "$seed" checkout -q -b "$dflt" 2>/dev/null
  gi "$seed" commit -q --allow-empty -m one
  gi "$seed" push -q origin "$dflt"
  git clone -q "$rem" "$w" 2>/dev/null
  gi "$w" checkout -q -b topic
  gi "$w" commit -q --allow-empty -m topic-work
  expect 0 "$dflt: up to date passes" "$w" 'git push -u origin topic'
  gi "$seed" commit -q --allow-empty -m two
  gi "$seed" push -q origin "$dflt"
  # The hook fetches itself, so the local copy of origin is stale on purpose.
  expect 2 "$dflt: behind is refused" "$w" 'git push origin topic'
  expect 2 "$dflt: behind via HEAD" "$w" 'git push -u origin HEAD'
  expect 2 "$dflt: behind via refspec" "$w" 'git push origin topic:topic'
  expect 2 "$dflt: behind via git -C" "$scratch" "git -C $w push origin topic"
  expect 2 "$dflt: behind via cd" "$scratch" "cd $w && git push origin topic"
  expect 2 "$dflt: behind via a bare push" "$w" 'git push'
  expect 2 "$dflt: behind via a forced refspec" "$w" 'git push origin +topic'
  expect 2 "$dflt: behind via a quoted branch" "$w" 'git push origin "topic"'
  expect 0 "$dflt: a git command before an out-of-scope push passes" "$w" 'git log -1; git push fork topic'
  expect 2 "$dflt: behind via a quoted git -C path" "$scratch" "git -C \"$w\" push origin topic"
  HOME="$scratch" expect 2 "$dflt: behind via cd ~" "$scratch" "cd ~/work-$dflt && git push origin topic"
  expect 0 "$dflt: a push in a commit message heredoc passes" "$w" "git commit -q --allow-empty -F - <<'MSG'
first line
git push origin topic
MSG"
  expect 2 "$dflt: a push after a commit message heredoc is checked" "$w" "git commit -q --allow-empty -F - <<'MSG'
first line
MSG
git push origin topic"
  expect 0 "$dflt: the word push outside git passes" "$w" 'git status; echo push'
  expect 0 "$dflt: delete passes" "$w" 'git push origin --delete topic'
  expect 0 "$dflt: other remote passes" "$w" 'git push fork topic'
  opt=off; expect 0 "$dflt: option off passes" "$w" 'git push origin topic'; opt=true
  gi "$w" rebase -q "origin/$dflt"
  expect 0 "$dflt: rebased passes" "$w" 'git push origin topic'
  gi "$seed" commit -q --allow-empty -m three
  gi "$seed" push -q origin "$dflt"
  # The local copy of origin shows the branch behind, so only the failed fetch lets it through.
  gi "$w" fetch -q origin
  gi "$w" remote set-url origin "$scratch/nowhere"
  expect 0 "$dflt: failed fetch lets it through" "$w" 'git push origin topic'
  gi "$w" remote set-url origin "$rem"
  gi "$w" checkout -q "$dflt"
  expect 0 "$dflt: pushing the default itself is out of scope" "$w" "git push origin $dflt"
  expect 2 "$dflt: naming a branch that is behind, from the default, is refused" "$w" 'git push origin topic'
  expect 0 "$dflt: HEAD on the default is out of scope" "$w" 'git push origin HEAD'
done
expect 0 "not a push passes" "$w" 'git status'
exit $fail
