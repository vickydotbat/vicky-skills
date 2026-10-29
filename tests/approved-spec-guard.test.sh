#!/usr/bin/env bash
# The guard asks before an edit to approved examples, found by file name or by an approved-spec mark, and stays silent otherwise.
set -u
guard="$(dirname "$0")/../plugins/vicky-skills/scripts/approved-spec-guard.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
printf '[Category("approved-spec")]\n' > "$dir/spec.cs"
printf 'plain test\n' > "$dir/plain.cs"
fail=0
run() { printf '{"tool_input":{"file_path":"%s"}}' "$1" | "$guard"; }
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got '$3'"; fail=1; fi; }
check "asks on a file marked approved-spec" ask "$(run "$dir/spec.cs" | jq -r .hookSpecificOutput.permissionDecision)"
check "silent on an unmarked file" "" "$(run "$dir/plain.cs")"
check "silent on a new file" "" "$(run "$dir/new.cs")"
check "asks on a file named for approved examples" ask "$(run "$dir/CharmApprovedExamples.cs" | jq -r .hookSpecificOutput.permissionDecision)"
exit $fail
