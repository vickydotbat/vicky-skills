#!/usr/bin/env bash
# approved-spec: the examples approved for S2 (F10). A script that lists
# approved tests by name and only runs them passes the approved-spec guard.
set -u
guard="$(dirname "$0")/../plugins/vicky-skills/scripts/approved-spec-guard.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
mkdir -p "$dir/tests"
git init -q "$dir"
printf 'echo ok\n' > "$dir/tests/charm_approved_examples.test.sh"
# runner.py lists the test by its bare name and runs it, as the mutation run does.
printf 'import subprocess\nTESTS = ["charm_approved_examples"]\nfor t in TESTS:\n    subprocess.run(["bash", "tests/" + t + ".test.sh"])\n' > "$dir/tests/runner.py"
# writer.py names the test file in full and writes into it.
printf 'with open("tests/charm_approved_examples.test.sh", "w") as f:\n    f.write("echo no\\n")\n' > "$dir/tests/writer.py"
fail=0
run() { jq -n --arg c "$1" --arg d "$dir" '{tool_name: "Bash", tool_input: {command: $c}, cwd: $d}' | bash "$guard" | jq -r '.hookSpecificOutput.permissionDecision // empty'; }
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got '$3', want '$2'"; fail=1; fi; }

# Given a script that lists approved tests by name and only runs them
# When the agent runs that script, as the mutation run does
# Then the guard lets it through
check "a runner that names and runs approved tests passes" "" "$(run "python3 tests/runner.py --check")"

# Given a script that names an approved test file and writes into it
# When the agent runs that script
# Then the guard refuses it
check "a script that writes an approved test is refused" deny "$(run "python3 tests/writer.py")"
exit $fail
