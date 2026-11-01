#!/usr/bin/env bash
# Approved examples for F9: a doc that shows the approved-spec mark stays editable, and a real test tag stays locked.
set -u
guard="$(dirname "$0")/../plugins/vicky-skills/scripts/approved-spec-guard.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
git init -q "$dir"
mark=approved-spec
fail=0
run() { printf '{"tool_input":{"file_path":"%s"}}' "$1" | "$guard" | jq -r '.hookSpecificOutput.permissionDecision // empty'; }
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got '$3'"; fail=1; fi; }

# E1. Given a Markdown doc whose prose and code sample both show the Category attribute with approved-spec,
#     When an agent edits the doc,
#     Then the guard lets the edit through.
printf 'Tag each one [Category("%s")].\n\n```cs\n[Category("%s")]\n```\n' "$mark" "$mark" > "$dir/TESTING_STANDARDS.md"
check "E1 a Markdown doc that shows the mark stays editable" "" "$(run "$dir/TESTING_STANDARDS.md")"

# E3. Given a script whose comment mentions the quoted name approved-spec in the middle of a sentence,
#     When an agent edits the script,
#     Then the guard lets the edit through.
printf '#!/bin/sh\n# The mark is a quoted "%s" or a tag.\necho hi\n' "$mark" > "$dir/helper.sh"
check "E3 a script that mentions the quoted mark in prose stays editable" "" "$(run "$dir/helper.sh")"

exit $fail
