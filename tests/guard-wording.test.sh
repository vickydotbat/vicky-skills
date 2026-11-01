#!/usr/bin/env bash
# How the guard reads what an Edit would leave: a single replacement changes
# the first match only, replace_all changes every match, and a tool whose
# result can't be read ahead is refused on a file whose wording is locked.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
guard="$root/plugins/vicky-skills/scripts/approved-spec-guard.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
git init -q "$dir"
f="$dir/charm_approved_examples.test.sh"
printf 'name=charm\n# Given a creature charmed by another\n# Then the charm ends\n' >"$f"
fail=0
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got '$3'"; fail=1; fi; }
run() { jq -n --arg f "$f" --argjson extra "$1" '{tool_name: "Edit", tool_input: ({file_path: $f, old_string: "charm", new_string: "spell"} + $extra)}' \
  | bash "$guard" | jq -r '.hookSpecificOutput.permissionDecision // empty'; }
check "a single replacement changes only the first match, a harness line, so it goes through" "" "$(run '{}')"
jq -n --arg f "$f" '{tool_name: "Edit", tool_input: {file_path: $f, old_string: "name=charm", new_string: "name=spell"}}' | bash "$guard" >/dev/null
check "a harness edit leaves the hook with exit 0, which lets the tool run" 0 "$?"
check "replace_all reaches the wording lines too, so it is refused" deny "$(run '{"replace_all": true}')"
notebook=$(jq -n --arg f "$f" '{tool_name: "NotebookEdit", tool_input: {notebook_path: $f, file_path: $f, new_source: "x"}}' \
  | bash "$guard" | jq -r '.hookSpecificOutput.permissionDecision // empty')
check "a tool whose result the guard can't read ahead is refused" deny "$notebook"
exit $fail
