#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2034,SC2069,SC2329 # check() evals its single-quoted condition later, which reads these names; a hook's stderr alone is read on purpose
# approved-spec: the examples approved on the note "LC-4 An approved test is
# locked". approved-test-lock.sh runs on PreToolUse for Edit, Write, MultiEdit
# and Bash. A test is approved when its file name holds approved_examples and
# main holds it. Its change record is a file on the branch, not on main, holding
# the line "<test path>:<line or new>" with "- [x] approve" under it, the
# red-pen section CHANGING.md names.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
scripts="$root/plugins/vicky-skills/scripts"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
hook="$scripts/approved-test-lock.sh"
fx=$(mktemp -d); trap 'rm -rf "$fx"' EXIT
repo="$fx/repo"; mkdir -p "$repo/tests"
git -C "$repo" init -q -b main; git -C "$repo" config user.email t@t; git -C "$repo" config user.name t
printf '# Given a thing\n# When it runs\n# Then it works\ncheck x\n' >"$repo/tests/foo_approved_examples.test.sh"
printf 'echo plain\n' >"$repo/tests/plain.test.sh"
git -C "$repo" add -A; git -C "$repo" commit -qm init; git -C "$repo" switch -qc work
f="$repo/tests/foo_approved_examples.test.sh"
pre() { jq -nc --arg d "$repo" "$1" | bash "$hook" 2>&1 >/dev/null; echo "exit=$?"; }
edit() { pre "{tool_name:\"Edit\",cwd:\$d,tool_input:{file_path:\"$1\",old_string:\"$2\",new_string:\"$3\"}}"; }

# Given a test file named after an approved example
# When the agent edits or deletes it
# Then the edit is refused
# And the agent reads that a change to an approved example goes through examples' CHANGING.md
out=$(edit "$f" "# Then it works" "# Then it passes")
check "LC-4 E1 an edit of an approved test is refused" 'grep -q "exit=2" <<<"$out" && grep -q "CHANGING.md" <<<"$out"'
out=$(pre "{tool_name:\"Bash\",cwd:\$d,tool_input:{command:\"rm $f\"}}")
check "LC-4 E1 deleting an approved test is refused" 'grep -q "exit=2" <<<"$out" && grep -q "CHANGING.md" <<<"$out"'

# Given a REPL script or shell command that writes a test file named after an approved example
# When it runs
# Then the write is refused, or reverted, with the CHANGING.md message
out=$(pre "{tool_name:\"Bash\",cwd:\$d,tool_input:{command:\"echo x > $f\"}}")
check "LC-4 E4 a shell write to an approved test is refused" 'grep -q "exit=2" <<<"$out" && grep -q "CHANGING.md" <<<"$out"'
out=$(pre "{tool_name:\"Write\",cwd:\$d,tool_input:{file_path:\"$f\",content:\"echo gone\\n\"}}")
check "LC-4 E4 a Write call, as a REPL script makes, is refused" 'grep -q "exit=2" <<<"$out" && grep -q "CHANGING.md" <<<"$out"'

# Given a test file no approved example names
# When the agent edits it
# Then the edit goes through
out=$(edit "$repo/tests/plain.test.sh" "echo plain" "echo other")
check "LC-4 E3 an edit of a plain test goes through" 'grep -qx "exit=0" <<<"$out"'

# Given a test file named after an approved example
# And CHANGING.md's change record for that example exists on the branch
# When the agent edits the test
# Then the edit goes through
mkdir -p "$repo/docs"; printf '## foo\n\ntests/foo_approved_examples.test.sh:3\n- [x] approve\n\n# Then it passes\n' >"$repo/docs/change.md"
git -C "$repo" add -A; git -C "$repo" commit -qm record
out=$(edit "$f" "# Then it works" "# Then it passes")
check "LC-4 E2 a change record on the branch lets the edit through" 'grep -qx "exit=0" <<<"$out"'

exit $fail
