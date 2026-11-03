#!/usr/bin/env bash
# approved-spec: the examples approved 2026-11-03 for "approved-spec guard
# lets a script that names approved tests run". The guard script is approved
# itself, so the commands name it from the repo root.
set -u
top="$(cd "$(dirname "$0")/.." && pwd)"
guard=plugins/vicky-skills/scripts/approved-spec-guard.sh
fail=0
run() { jq -n --arg c "$1" --arg d "$top" '{tool_name: "Bash", tool_input: {command: $c}, cwd: $d}' | bash "$top/$guard" | jq -rs '.[0].hookSpecificOutput.permissionDecision // "allow"'; }
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got '$3', want '$2'"; fail=1; fi; }

# Given the approved-spec guard script, which is approved itself
# When the agent runs grep on the guard, then python3 tests/mutate-hooks.py --check, in one command
# Then the command runs, because a script run by path only reads the guard
check "a grep and a script run by path" allow "$(run "grep -c x $guard; python3 tests/mutate-hooks.py --check")"

# Given the same guard script
# When the agent runs python3 -c with code that writes to the guard
# Then the guard still refuses it
check "python3 -c writing the guard" deny "$(run "python3 -c \"open('$guard', 'a').write('x')\"")"
exit $fail
