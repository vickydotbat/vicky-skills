#!/usr/bin/env bash
# Regression: a read-only grep whose pattern holds an escaped pipe passes the
# approved-spec guard, though the file it reads names an approved-examples
# file. The pipe inside the quotes is part of the pattern, not a pipeline.
set -u
guard="${GUARD:-$(dirname "$0")/../plugins/vicky-skills/scripts/approved-spec-guard.sh}"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
git init -q "$dir"
printf 'plain test\n' > "$dir/CharmApprovedExamples.cs"
printf 'sed -i s/a/b/ CharmApprovedExamples.cs\n' > "$dir/fix.sh"; chmod +x "$dir/fix.sh"
cp "$dir/fix.sh" "$dir/notes.txt"; chmod -x "$dir/notes.txt"
git -C "$dir" add -A && git -C "$dir" -c user.name=t -c user.email=t@example.invalid commit -qm fixtures
fail=0
sh_run() { jq -n --arg c "$1" --arg d "$dir" '{tool_name: "Bash", tool_input: {command: $c}, cwd: $d}' | "$guard" | jq -r '.hookSpecificOutput.permissionDecision // empty'; }
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got '$3'"; fail=1; fi; }
check "silent on a plain file grepped with an escaped pipe in the pattern" "" "$(sh_run 'grep -n -i "card\|shot\|^#" notes.txt')"
check "silent on an executable script grepped with an escaped pipe in the pattern" "" "$(sh_run 'grep -n "a\|b" fix.sh')"
check "silent on a single-quoted escaped-pipe pattern" "" "$(sh_run "grep -n 'a\\|b' notes.txt")"
check "still refuses a script run after a quoted pattern" deny "$(sh_run 'echo "a|b"; bash fix.sh')"
check "still refuses a script run through bash -c" deny "$(sh_run 'bash -c "./fix.sh"')"
check "silent on a script named only in a comment" "" "$(sh_run 'echo hi # bash fix.sh')"
check "still refuses a script run through nix shell with a flake reference" deny "$(sh_run 'nix shell nixpkgs#jq --command ./fix.sh')"
check "still refuses a script run after a word that starts with a hash" deny "$(sh_run 'env #c ./fix.sh')"
check "still refuses a plain script run" deny "$(sh_run 'bash fix.sh')"
exit $fail
