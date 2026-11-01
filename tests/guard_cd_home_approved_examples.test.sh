#!/usr/bin/env bash
# approved-spec: the examples approved for S2 (F3). The approved-spec guard
# reads a command's files from the folder a leading cd ~/ moves to.
set -u
guard="$(dirname "$0")/../plugins/vicky-skills/scripts/approved-spec-guard.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
test=tests/charm_approved_examples.test.sh
# home: a stand-in home folder holding a checkout with an approved test.
# session: the session's folder, with no such test.
mkdir -p "$dir/home/tree/tests" "$dir/session"
printf 'echo ok\n' > "$dir/home/tree/$test"
git init -q "$dir/home/tree"
fail=0
run() { jq -n --arg c "$1" --arg d "$dir/session" '{tool_name: "Bash", tool_input: {command: $c}, cwd: $d}' | HOME="$dir/home" bash "$guard" | jq -r '.hookSpecificOutput.permissionDecision // empty'; }
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got '$3', want '$2'"; fail=1; fi; }

# Given an approved test in a folder under my home folder
# When a command that starts with cd ~/ into that folder edits the test
# Then the guard refuses it
check "cd ~/ then edit is refused" deny "$(run "cd ~/tree && sed -i s/ok/no/ $test")"

# Given an approved test in a folder under my home folder
# When a command that starts with cd ~/ into that folder only runs the test
# Then the guard lets it through
check "cd ~/ then run passes" "" "$(run "cd ~/tree && bash $test")"
exit $fail
