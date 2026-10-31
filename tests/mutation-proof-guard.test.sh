#!/usr/bin/env bash
# The proof guard's decisions the approved examples leave out: a git command
# that is no commit, and a commit made from a folder below the repo root.
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
exit $fail
