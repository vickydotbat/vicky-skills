#!/usr/bin/env bash
# approved-spec: the fixture-name examples, approved 2026-11-02. The guard
# runs on a command in a scratch repo, with the scripts it runs on disk.
set -u
guard="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/approved-spec-guard.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
git init -q "$dir"; mkdir "$dir/tests"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
decision() { jq -n --arg c "$1" --arg d "$dir" '{tool_name: "Bash", tool_input: {command: $c}, cwd: $d}' | bash "$guard" | jq -r '.hookSpecificOutput.permissionDecision // empty'; }
printf '#!/usr/bin/env bash\ntmp=$(mktemp -d)\nprintf x > "$tmp/tests/a_approved_examples.test.sh"\n' > "$dir/tests/hook-exits.test.sh"
printf '# Given a hook\nexit 0\n' > "$dir/tests/real_approved_examples.test.sh"
git -C "$dir" add tests/real_approved_examples.test.sh
printf '#!/usr/bin/env bash\nprintf x > tests/real_approved_examples.test.sh\n' > "$dir/tests/clobber.sh"

# Given a test that makes a scratch file whose name looks like an approved test's, and the repo holds no such file
# When the agent runs that test
# Then the command goes through
check "a scratch fixture named like an approved test is not one" '[ -z "$(decision "bash tests/hook-exits.test.sh | grep FAIL")" ]'

# Given a script that names an approved test the repo does hold, and writes to it
# When the agent runs that script
# Then the command is refused, as before
check "a script that names a real approved test still stops" '[ "$(decision "bash tests/clobber.sh")" = deny ]'
exit $fail
