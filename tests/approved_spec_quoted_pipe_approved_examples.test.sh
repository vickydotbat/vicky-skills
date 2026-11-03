#!/usr/bin/env bash
# approved-spec: the examples approved 2026-11-03 for "approved-spec guard
# reads a pipe inside quotes as text". The guard runs on a fixture repo that
# holds one approved test file.
set -u
guard="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/approved-spec-guard.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
git init -q "$dir"
printf '#!/usr/bin/env bash\n# approved-spec: fixture\n# Given a\n# When b\n# Then c\n' > "$dir/x_approved_examples.test.sh"
fail=0
run() { jq -n --arg c "$1" --arg d "$dir" '{tool_name: "Bash", tool_input: {command: $c}, cwd: $d}' | bash "$guard" | jq -rs '.[0].hookSpecificOutput.permissionDecision // "allow"'; }
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got '$3', want '$2'"; fail=1; fi; }

# Given an approved test file
# When the agent runs grep -E 'a|rm x' on that file
# Then the command runs, because the pipe and the rm sit inside the quotes
check "a quoted pipe and rm are text" allow "$(run "grep -E 'a|rm x' x_approved_examples.test.sh")"

# Given an approved test file
# When the agent runs grep -c x on that file, piped to rm on the same file
# Then the guard still refuses it
check "a real pipe to rm is refused" deny "$(run "grep -c x x_approved_examples.test.sh | rm x_approved_examples.test.sh")"
exit $fail
