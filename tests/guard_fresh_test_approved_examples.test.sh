#!/usr/bin/env bash
# approved-spec: the examples approved on the star "approved-spec-guard frees
# a new test with no wording yet". Each check is named after its example.
set -u
guard="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/approved-spec-guard.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
git init -q "$dir"
printf 'readme\n' > "$dir/README"
printf 'plain test\n' > "$dir/OldApprovedExamples.cs"
git -C "$dir" add -A && git -C "$dir" -c user.name=t -c user.email=t@example.invalid commit -qm fixtures
printf 'plain test\n' > "$dir/NewApprovedExamples.cs"
printf '// Given a charm\n// When it is cast\n// Then it glows\ntest\n' > "$dir/WordedApprovedExamples.cs"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
decide() { bash "$guard" | jq -r '.hookSpecificOutput.permissionDecision // empty'; }
edit() { jq -n --arg f "$dir/$1" --arg o "$2" --arg n "$3" '{tool_name: "Edit", tool_input: {file_path: $f, old_string: $o, new_string: $n}}' | decide; }
write() { jq -n --arg f "$dir/$1" '{tool_name: "Write", tool_input: {file_path: $f, content: "x\n"}}' | decide; }
shell() { jq -n --arg c "$1" --arg d "$dir" '{tool_name: "Bash", tool_input: {command: $c}, cwd: $d}' | decide; }

# Given a new approved test, not yet committed, with no Given, When or Then lines
# When an agent edits it with Edit, Write or a shell command
# Then the edit goes through
check "a new approved test with no wording yet is edited through Edit, Write and a shell command" \
  '[ -z "$(edit NewApprovedExamples.cs plain fine)" ] && [ -z "$(write NewApprovedExamples.cs)" ] && [ -z "$(shell "sed -i s/plain/fine/ NewApprovedExamples.cs")" ]'
# Given an approved test already committed, with no Given, When or Then lines
# When an agent edits it
# Then the edit is refused, as today
check "a committed approved test with no wording is refused" \
  '[ "$(edit OldApprovedExamples.cs plain fine)" = deny ] && [ "$(shell "sed -i s/plain/fine/ OldApprovedExamples.cs")" = deny ]'
# Given a new approved test, not yet committed, that already holds Given, When and Then lines
# When an agent's edit changes one of them
# Then the edit is refused
check "a new approved test's written wording is refused" \
  '[ "$(edit WordedApprovedExamples.cs "it glows" "it hums")" = deny ]'
exit $fail
