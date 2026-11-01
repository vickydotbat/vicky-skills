#!/usr/bin/env bash
# approved-spec: the examples the user set on 2026-11-01 for the approved-spec
# guard: it locks an approved test's wording, its Given, When and Then comment
# lines, and lets the rest of the file change through Edit and Write.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
guard="$root/plugins/vicky-skills/scripts/approved-spec-guard.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
git init -q "$dir/repo"; mkdir -p "$dir/repo/tests"
f="$dir/repo/tests/charm_approved_examples.test.sh"
cat >"$f" <<'EOF'
#!/usr/bin/env bash
setup() { echo one; }
# Given a creature charmed by another
# When its charmer hits it
# Then the charm ends
check_charm() { setup; }
EOF
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
decision() { jq -r '.hookSpecificOutput.permissionDecision // empty'; }
reason() { jq -r '.hookSpecificOutput.permissionDecisionReason // empty'; }
edit() { jq -n --arg f "$f" --arg o "$1" --arg n "$2" '{tool_name: "Edit", tool_input: {file_path: $f, old_string: $o, new_string: $n}}' | bash "$guard"; }
write() { jq -n --arg f "$f" --arg c "$1" '{tool_name: "Write", tool_input: {file_path: $f, content: $c}}' | bash "$guard"; }
shell() { jq -n --arg c "$1" --arg d "$dir/repo" '{tool_name: "Bash", tool_input: {command: $c}, cwd: $d}' | bash "$guard"; }

# Given an approved test file whose examples are written in it as Given, When and Then comment lines
# When the agent changes a line outside them with the Edit or Write tool, such as a setup step or a helper
# Then the edit goes through, with no sign-off from the user
harness_edit=$(edit 'setup() { echo one; }' 'setup() { echo two; }')
harness_write=$(write "$(sed 's/echo one/echo two/' "$f")")
check "G1 a harness edit to an approved test, by Edit or Write, goes through with no sign-off" \
  '[ -z "$(decision <<<"$harness_edit")" ] && [ -z "$(decision <<<"$harness_write")" ]'

# Given the same approved test file
# When the agent's edit changes, adds or removes a Given, When or Then line
# Then the edit is refused, the refusal quotes the line, and it steers the agent to red-pen as today
changed=$(edit '# Then the charm ends' '# Then the charm ends at once')
added=$(edit '# Then the charm ends' $'# Then the charm ends\n# And the charmer is hostile')
removed=$(write "$(grep -v '^# When' "$f")")
check "G2 an edit that changes, adds or removes a Given, When or Then line is refused, quotes the line, and steers to red-pen" \
  '[ "$(decision <<<"$changed")" = deny ] && [ "$(decision <<<"$added")" = deny ] && [ "$(decision <<<"$removed")" = deny ] && grep -qF "# Then the charm ends" <<<"$(reason <<<"$changed")" && grep -qF "# And the charmer is hostile" <<<"$(reason <<<"$added")" && grep -qF "# When its charmer hits it" <<<"$(reason <<<"$removed")" && grep -q "Changing an approved example" <<<"$(reason <<<"$changed")"'

# Given an approved test file with its examples written in it
# When a Bash command writes the file, such as sed -i or a redirect
# Then it is refused, and the refusal says a harness edit goes through with the Edit tool
by_sed=$(shell "sed -i s/one/two/ tests/charm_approved_examples.test.sh")
by_redirect=$(shell "echo x >> tests/charm_approved_examples.test.sh")
check "G4 a Bash command that writes an approved test is refused, and told a harness edit goes through with the Edit tool" \
  '[ "$(decision <<<"$by_sed")" = deny ] && [ "$(decision <<<"$by_redirect")" = deny ] && grep -q "Edit tool" <<<"$(reason <<<"$by_sed")"'
exit $fail
