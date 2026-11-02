#!/usr/bin/env bash
# A regression test: a test with approved examples under any name runs
# freely, and a write onto it still refuses. Approved 2026-11-02 as examples,
# but the behaviour already held, so it carries no approved-spec mark.
set -u
guard="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/approved-spec-guard.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
git init -q "$dir"; mkdir "$dir/tests"
# A test that holds approved examples and makes a fixture named like an approved test in a scratch folder.
printf '#!/usr/bin/env bash\n# approved-spec: a hook'"'"'s exits\n# Given a hook\n# When it runs\n# Then it exits 0\nprintf x > "$tmp/plain/tests/a_approved_examples.test.sh"\nexit 0\n' > "$dir/tests/hook-exits.test.sh"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
decision() { jq -n --arg c "$1" --arg d "$dir" '{tool_name: "Bash", tool_input: {command: $c}, cwd: $d}' | bash "$guard" | jq -r '.hookSpecificOutput.permissionDecision // empty'; }

# a test file that holds approved examples under any name, such as hook-exits.test.sh
# the agent runs it with bash, or pipes its output to grep
# the command goes through
check "running a test is not editing it" '[ -z "$(decision "bash tests/hook-exits.test.sh | grep FAIL")" ] && [ -z "$(decision "bash tests/hook-exits.test.sh")" ] && [ -z "$(decision "sh tests/hook-exits.test.sh; echo done")" ]'

# the same test file
# the agent's command writes to it, such as sed -i or a redirect onto it
# the command is refused, as before
check "a write still stops" '[ "$(decision "sed -i s/0/1/ tests/hook-exits.test.sh")" = deny ] && [ "$(decision "echo x > tests/hook-exits.test.sh")" = deny ] && [ "$(decision "bash tests/hook-exits.test.sh > tests/hook-exits.test.sh")" = deny ]'
exit $fail
