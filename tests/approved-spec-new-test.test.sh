#!/usr/bin/env bash
# The approved-examples guard's refusal names a home for a test no example
# approved (a regression or edge-case test): a test file of its own, which
# needs no draft.
set -u
guard="$(dirname "$0")/../plugins/vicky-skills/scripts/approved-spec-guard.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
git init -q "$dir"
printf 'plain test\n' > "$dir/CharmApprovedExamples.cs"
git -C "$dir" add -A && git -C "$dir" -c user.name=t -c user.email=t@example.invalid commit -qm fixtures
fail=0
reason() { jq -n --arg f "$dir/CharmApprovedExamples.cs" '{tool_input: {file_path: $f}}' | bash "$guard" | jq -r '.hookSpecificOutput.permissionDecisionReason // empty'; }
if reason | grep -q 'A new test that no example approved goes in a test file of its own'; then
  echo "ok   the refusal sends a new unapproved test to a test file of its own"
else
  echo "FAIL the refusal sends a new unapproved test to a test file of its own"; fail=1
fi
# An append through the shell gets the same steer.
append=$(jq -n --arg d "$dir" '{tool_name: "Bash", tool_input: {command: "cat new-test.cs >> CharmApprovedExamples.cs"}, cwd: $d}' | bash "$guard" | jq -r '.hookSpecificOutput.permissionDecisionReason // empty')
if grep -q 'A new test that no example approved goes in a test file of its own' <<<"$append"; then
  echo "ok   an append to the approved file gets the same steer"
else
  echo "FAIL an append to the approved file gets the same steer"; fail=1
fi
exit $fail
