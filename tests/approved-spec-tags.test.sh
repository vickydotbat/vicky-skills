#!/usr/bin/env bash
# Regression: a real test tag stays locked. These held before F9, so they carry no mark and sit apart from its approved examples.
set -u
guard="$(dirname "$0")/../plugins/vicky-skills/scripts/approved-spec-guard.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
git init -q "$dir"
mark=approved-spec
fail=0
run() { printf '{"tool_input":{"file_path":"%s"}}' "$1" | "$guard" | jq -r '.hookSpecificOutput.permissionDecision // empty'; }
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got '$3'"; fail=1; fi; }

# Given a C# test file tagged with the Category attribute approved-spec,
#     When an agent edits it,
#     Then the guard refuses the edit.
printf '[Category("%s")]\npublic void Charms() {}\n' "$mark" > "$dir/Charm.cs"
check "a C# test tagged with the mark is refused" deny "$(run "$dir/Charm.cs")"

# Given a Python test with a comment line that opens with approved-spec and a colon,
#     When an agent edits it,
#     Then the guard refuses the edit.
printf '# %s: charm\ndef test_charm():\n    pass\n' "$mark" > "$dir/test_charm.py"
check "a Python test whose comment line opens with the mark is refused" deny "$(run "$dir/test_charm.py")"

# A comment that names the mark and a colon mid-sentence is prose, not a tag.
printf '#!/bin/sh\n# Mark a test with %s: in a comment line.\necho hi\n' "$mark" > "$dir/notes.sh"
check "a comment that names the mark mid-line stays editable" "" "$(run "$dir/notes.sh")"

# Every prose format holds no tests, whatever it shows.
for ext in md markdown rst adoc txt; do
  printf '[Category("%s")]\n' "$mark" > "$dir/doc.$ext"
  check "a .$ext doc that shows the tag stays editable" "" "$(run "$dir/doc.$ext")"
done

# The comment mark quoted inside a sentence is prose.
printf '#!/bin/sh\n# A comment "# %s:" marks a test.\n' "$mark" > "$dir/quoted.sh"
check "a comment that quotes the comment mark stays editable" "" "$(run "$dir/quoted.sh")"
# A comment line that opens with the name but no colon is prose.
printf '#!/bin/sh\n# %s guard notes\n' "$mark" > "$dir/heading.sh"
check "a comment line that opens with the name and no colon stays editable" "" "$(run "$dir/heading.sh")"
# The name as a later argument of a tag still marks the test.
printf '[Category("unit", "%s")]\n' "$mark" > "$dir/Two.cs"
check "a tag with the mark as its second argument is refused" deny "$(run "$dir/Two.cs")"

# A tagged test outside every git checkout is no contract.
out=$(mktemp -d); printf '[Category("%s")]\n' "$mark" > "$out/Loose.cs"
check "a tagged test outside every checkout stays editable" "" "$(run "$out/Loose.cs")"
rm -rf "$out"

exit $fail
