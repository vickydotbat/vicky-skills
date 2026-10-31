#!/usr/bin/env bash
# The approved-spec guard lets a mutation pass run through its wrapper, and
# keeps its own script locked. Both examples were approved on the ticket
# "approved-spec guard refuses scripts that only name approved tests". The
# guard already behaved this way, so these tests guard against a regression
# and can't pass the red-first check an approved-examples file must pass.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
guard="$root/plugins/vicky-skills/scripts/approved-spec-guard.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
fail=0
decide() { bash "$guard" | jq -r '.hookSpecificOutput.permissionDecision // empty'; }
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got '$3', want '$2'"; fail=1; fi; }

for c in "bash tests/mutate-hooks.sh approved-spec-guard.sh" "tests/mutate-hooks.sh --survivors"; do
  check "given the repo's mutation pass, started with tests/mutate-hooks.sh ($c), the guard lets it through" \
    "" "$(jq -n --arg c "$c" --arg d "$root" '{tool_name: "Bash", tool_input: {command: $c}, cwd: $d}' | decide)"
done
# A copy in a fresh checkout has no grant to open it.
git init -q "$dir"
cp "$guard" "$dir/approved-spec-guard.sh"
check "given an edit to the approved-spec guard script, when no grant exists for it, the guard refuses it" \
  deny "$(jq -n --arg f "$dir/approved-spec-guard.sh" '{tool_name: "Edit", tool_input: {file_path: $f}}' | decide)"
exit $fail
