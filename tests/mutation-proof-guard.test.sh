#!/usr/bin/env bash
# The proof guard's decisions the approved examples leave out: a git command
# that is no commit, a commit made from a folder below the repo root, and the
# steer for a stale change that this commit leaves out.
set -u
guard="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/mutation-proof-guard.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
repo="$dir/repo"; git init -q "$repo"; mkdir -p "$repo/docs/agents" "$repo/sub"
printf 'Mutation proof check: bash check.sh\n' > "$repo/docs/agents/testing.md"
printf 'exit 1\n' > "$repo/check.sh"
fail=0
expect() { # name want cwd command
  jq -n --arg c "$4" --arg d "$3" '{tool_name: "Bash", tool_input: {command: $c}, cwd: $d}' |
    CLAUDE_PLUGIN_OPTION_GUARD_MUTATION_PROOF=true bash "$guard" >/dev/null 2>&1; got=$?
  if [ "$got" = "$2" ]; then echo "ok   $1"; else echo "FAIL $1: exit $got, want $2"; fail=1; fi
}
expect "a git command that is no commit runs, with the proof stale" 0 "$repo" 'git status'
expect "a commit from a folder below the root is checked from the root" 2 "$repo/sub" 'git commit -m x'
msg=$(jq -n --arg d "$repo" '{tool_name: "Bash", tool_input: {command: "git commit -m x"}, cwd: $d}' |
  CLAUDE_PLUGIN_OPTION_GUARD_MUTATION_PROOF=true bash "$guard" 2>&1 >/dev/null)
grep -q "not part of this commit.*git restore it, commit, then copy it back" <<<"$msg" \
  && echo "ok   the refusal says how to commit around a stale change the commit leaves out" \
  || { echo "FAIL the refusal has no steer for a stale change outside the commit: $msg"; fail=1; }
# What a commit takes: approved tests alone pass, anything more is checked.
mkdir -p "$repo/tests"; : > "$repo/tests/a_approved_examples.test.sh"; : > "$repo/tests/BApprovedExamples.cs"
git -C "$repo" add check.sh && git -C "$repo" -c user.name=t -c user.email=t@example.invalid commit -qm base
echo 'exit 1 # changed' > "$repo/check.sh"
expect "approved tests named in an add pass" 0 "$repo" 'git add -v tests/a_approved_examples.test.sh tests/BApprovedExamples.cs && git commit -m red'
expect "an add -A takes the changed script too" 2 "$repo" 'git add -A && git commit -m x'
expect "an add . takes the changed script too" 2 "$repo" 'git add . && git commit -m x'
expect "an add -u takes the changed script too" 2 "$repo" 'git add -u; git commit -m x'
expect "an add --all takes the changed script too" 2 "$repo" 'git add --all && git commit -m x'
expect "a commit --all takes the changed script too" 2 "$repo" 'git add tests/a_approved_examples.test.sh && git commit --all -m x'
expect "a commit -qam takes the changed script too" 2 "$repo" 'git add tests/a_approved_examples.test.sh && git commit -qam x'
git -C "$repo" add tests/a_approved_examples.test.sh
expect "a staged approved test alone passes" 0 "$repo" 'git commit -m red'
expect "a staged approved test plus a named script is checked" 2 "$repo" 'git add check.sh && git commit -m x'
expect "a commit with --amend and no a flag takes only what is staged" 0 "$repo" 'git commit --amend -m red'
git -C "$repo" reset -q
expect "a commit of nothing staged is still checked" 2 "$repo" 'git commit -m x'
exit $fail
