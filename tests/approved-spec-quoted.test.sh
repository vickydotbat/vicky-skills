#!/usr/bin/env bash
# The guard reads single-quoted text as text, except where the quotes hold the
# file's own name: a quoted redirect target is still a write to it.
set -u
guard="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/approved-spec-guard.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
git init -q "$dir"
printf 'plain test\n' > "$dir/CharmApprovedExamples.cs"
fail=0
run() { jq -n --arg c "$1" --arg d "$dir" '{tool_name: "Bash", tool_input: {command: $c}, cwd: $d}' | bash "$guard" | jq -rs '.[0].hookSpecificOutput.permissionDecision // "allow"'; }
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got '$3', want '$2'"; fail=1; fi; }
check "a redirect to the file in quotes is refused" deny "$(run "echo hi > 'CharmApprovedExamples.cs'")"
check "a quoted pattern beside the file runs" allow "$(run "grep -c 'a|tee b' CharmApprovedExamples.cs")"
exit $fail
