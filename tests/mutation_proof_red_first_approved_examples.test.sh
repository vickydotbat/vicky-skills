#!/usr/bin/env bash
# approved-spec: the mutation proof examples, approved 2026-11-02. The guard
# runs on a commit in a scratch repo whose proof check always reports stale.
set -u
guard="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/mutation-proof-guard.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
repo="$dir/repo"; git init -q "$repo"; mkdir -p "$repo/docs/agents" "$repo/tests" "$repo/scripts"
printf 'Mutation proof check: echo "stale: hook.sh"; exit 1\n' > "$repo/docs/agents/testing.md"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
commit() { jq -n --arg c "$1" --arg d "$repo" '{tool_name: "Bash", tool_input: {command: $c}, cwd: $d}' |
  CLAUDE_PLUGIN_OPTION_GUARD_MUTATION_PROOF=true bash "$guard" >/dev/null 2>&1; }
echo 'exit 1' > "$repo/tests/hook_approved_examples.test.sh"
echo 'exit 1' > "$repo/scripts/hook.sh"
git -C "$repo" add scripts/hook.sh && git -C "$repo" -c user.name=t -c user.email=t@example.invalid commit -qm base
echo 'exit 0' > "$repo/scripts/hook.sh"

# Given approved examples for a hook, written and run red before its code
# When the agent commits them on their own, as red-first asks
# Then the commit goes through, and the mutation proof is asked for with the code commit that turns them green
check "red approved tests commit on their own" 'commit "git add tests/hook_approved_examples.test.sh && git commit -m red" && (cd "$repo" && git add tests/hook_approved_examples.test.sh) && commit "git commit -m red"'

# Given a hook script changed and its mutation proof out of date
# When the agent commits the script
# Then the commit is refused until the proof is refreshed, as before
check "a stale proof still stops a code commit" '! commit "git add scripts/hook.sh tests/hook_approved_examples.test.sh && git commit -m green" && ! commit "git commit -am green"'
exit $fail
