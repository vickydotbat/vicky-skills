#!/usr/bin/env bash
# restack-origin-guard refuses a git-spice command that rebases onto trunk
# while the local trunk differs from origin's, since git-spice rebases onto
# the local branch. Covers each refused form, each pass, the setting off, a
# failed fetch and bad input.
set -u
hook="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/restack-origin-guard.sh"
scratch=$(mktemp -d); trap 'rm -rf "$scratch"' EXIT
fail=0
opt=true
expect() {
  local want=$1 label=$2 cwd=$3 cmd=$4 got
  got=$(jq -n --arg c "$cmd" --arg d "$cwd" '{cwd:$d,tool_input:{command:$c}}' |
    CLAUDE_PLUGIN_OPTION_GUARD_RESTACK_ORIGIN=$opt "$hook" >/dev/null 2>"$scratch/err"; echo $?)
  if [ "$got" = "$want" ]; then echo "ok   $label"; else echo "FAIL $label: want $want, got $got"; fail=1; fi
}
gi() { git -C "$1" -c user.email=t@t -c user.name=t -c commit.gpgsign=false "${@:2}"; }

mkdir -p "$scratch/plain"
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
  expect 0 "$dflt: a restack with trunk matching origin passes" "$w" "gs branch onto $dflt"
  gi "$seed" commit -q --allow-empty -m two
  gi "$seed" push -q origin "$dflt"
  # The hook fetches itself, so the local trunk is stale on purpose.
  for c in "gs branch onto $dflt" "gs bon $dflt" "gs b on $dflt" "gs branch create next" "gs bc next" "gs branch restack" "gs br" \
           "gs upstack onto $dflt" "gs uso $dflt" "gs us r" "gs upstack restack" "gs downstack restack" "gs dsr" \
           "gs stack restack" "gs sr" "gs s r" "gs repo restack" "gs rr" "gs --verbose stack restack"; do
    expect 2 "$dflt: '$c' with a stale local trunk is refused" "$w" "$c"
  done
  expect 2 "$dflt: via gs -C" "$scratch" "gs -C $w stack restack"
  expect 2 "$dflt: via cd" "$scratch" "cd $w && gs sr"
  expect 2 "$dflt: after another command" "$w" "git status; gs sr"
  check_msg() { grep -q "gs repo sync" "$scratch/err" && grep -q "git fetch origin $dflt:$dflt" "$scratch/err" && grep -q "Nothing in this command ran" "$scratch/err"; }
  expect 2 "$dflt: the refusal names the fixes" "$w" "gs sr"
  if check_msg; then echo "ok   $dflt: refusal text"; else echo "FAIL $dflt: refusal text"; fail=1; fi
  expect 0 "$dflt: a sync earlier in the command passes" "$w" "gs repo sync && gs stack restack"
  expect 0 "$dflt: a short sync earlier passes" "$w" "gs rs && gs sr"
  expect 0 "$dflt: a trunk fetch earlier passes" "$w" "git fetch origin $dflt:$dflt && gs sr"
  expect 0 "$dflt: a trunk reset to origin earlier passes" "$w" "git branch -f $dflt origin/$dflt; gs sr"
  expect 2 "$dflt: a sync after the restack does not count" "$w" "gs sr && gs repo sync"
  for c in "gs log short" "gs ls" "gs stack submit" "gs ss" "gs commit create" "gs cc" "gs branch checkout x" "gs repo sync"; do
    expect 0 "$dflt: '$c' is no restack onto trunk and passes" "$w" "$c"
  done
  expect 0 "$dflt: a restack named only inside quotes passes" "$w" 'echo "gs stack restack"'
  expect 0 "$dflt: another command that spells a restack passes" "$w" "gs log short; echo stack restack"
  expect 2 "$dflt: an empty segment before the restack is skipped" "$w" " ; gs sr"
  expect 0 "$dflt: a cd into a missing folder passes" "$w" "cd $scratch/missing && gs sr"
  expect 0 "$dflt: a gs -C outside a repository passes" "$w" "gs -C $scratch/plain sr"
  gi "$w" remote set-head origin -d
  expect 2 "$dflt: with no origin/HEAD, trunk is still found" "$w" "gs sr"
  if [ "$dflt" = main ]; then
    gi "$seed" push -q origin main:master; gi "$w" fetch -q origin
    expect 2 "main: with no origin/HEAD and both names on origin, main is trunk" "$w" "gs sr"
    gi "$seed" push -q origin --delete master; gi "$w" fetch -q --prune origin
  fi
  gi "$w" remote set-head origin "$dflt"
  expect 0 "$dflt: a restack inside a commit message passes" "$w" "git commit -m 'then gs sr'"
  gi "$w" fetch -q origin "$dflt:$dflt"
  expect 0 "$dflt: a trunk brought up to date passes" "$w" "gs sr"
  gi "$w" checkout -q "$dflt"; gi "$w" commit -q --allow-empty -m local-only; gi "$w" checkout -q topic
  expect 2 "$dflt: a local trunk ahead of origin is refused too" "$w" "gs sr"
  opt=false; expect 0 "$dflt: setting off passes" "$w" "gs sr"; opt=0; expect 0 "$dflt: setting 0 passes" "$w" "gs sr"; opt=true
  gi "$w" remote set-url origin "$scratch/nowhere"
  expect 0 "$dflt: a fetch that fails lets it through" "$w" "gs sr"
  if grep -q "could not fetch" "$scratch/err"; then echo "ok   $dflt: says the fetch failed"; else echo "FAIL $dflt: says the fetch failed"; fail=1; fi
  gi "$w" remote set-url origin "$rem"
done
nt="$scratch/no-trunk"; git init -q -b topic "$nt"; gi "$nt" commit -q --allow-empty -m x
expect 0 "a repo with no origin passes" "$nt" "gs sr"
nl="$scratch/no-local"; git clone -q "$scratch/rem-main" "$nl" 2>/dev/null; gi "$nl" checkout -q -b topic; gi "$nl" branch -q -D main
gi "$scratch/seed-main" commit -q --allow-empty -m three; gi "$scratch/seed-main" push -q origin main
expect 0 "a clone with no local trunk passes" "$nl" "gs sr"
expect 0 "a missing working folder passes" "$scratch/gone" "gs sr"
expect 0 "outside a repository passes" "$scratch/plain" "gs sr"
got=$(printf 'not json' | CLAUDE_PLUGIN_OPTION_GUARD_RESTACK_ORIGIN=true "$hook" >/dev/null 2>&1; echo $?)
if [ "$got" = 0 ]; then echo "ok   input that isn't JSON passes"; else echo "FAIL input that isn't JSON: got $got"; fail=1; fi
got=$(jq -n '{cwd:"/",tool_input:{command:"gs sr"}}' | PATH=/nonexistent CLAUDE_PLUGIN_OPTION_GUARD_RESTACK_ORIGIN=true "$BASH" "$hook" 2>&1 >/dev/null; echo "|$?")
if [[ "$got" == *"is missing, so this guard is off"*"|0" ]]; then echo "ok   with jq or git missing it says so and passes"; else echo "FAIL missing tools: $got"; fail=1; fi
exit $fail
