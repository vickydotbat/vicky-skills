#!/usr/bin/env bash
# approved-spec.sh decides whether a file holds approved examples: by its name,
# or by a test framework's mark inside it, and never for a backup copy or a
# prose file that only mentions the mark.
set -u
. "$(dirname "$0")/../plugins/vicky-skills/scripts/approved-spec.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
git init -q "$dir"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
printf 'echo hi\n' > "$dir/charm_approved_examples.test.sh"
printf '# approved-spec: charm\necho hi\n' > "$dir/charm.test.sh"
printf 'echo hi\n' > "$dir/plain.test.sh"
printf 'echo hi\n' > "$dir/charm_approved_examples.test.sh.bak"
printf '# approved-spec: charm\n' > "$dir/notes.md"
check "a file named for approved examples is approved" 'approved "$dir/charm_approved_examples.test.sh"'
check "a file holding the mark is approved" 'approved "$dir/charm.test.sh"'
check "a plain test file is not approved" '! approved "$dir/plain.test.sh"'
check "a backup copy is not approved" '! approved "$dir/charm_approved_examples.test.sh.bak"'
check "a prose file that names the mark is not approved" '! approved "$dir/notes.md"'
exit $fail
