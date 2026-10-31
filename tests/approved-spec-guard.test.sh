#!/usr/bin/env bash
# The guard asks before an edit to approved examples, found by file name or by an approved-spec mark, and stays silent otherwise.
set -u
guard="$(dirname "$0")/../plugins/vicky-skills/scripts/approved-spec-guard.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
printf '[Category("approved-spec")]\n' > "$dir/spec.cs"
printf 'plain test\n' > "$dir/plain.cs"
printf 'plain test\n' > "$dir/CharmApprovedExamples.cs"
fail=0
run() { printf '{"tool_input":{"file_path":"%s"}}' "$1" | "$guard"; }
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got '$3'"; fail=1; fi; }
check "asks on a file marked approved-spec" ask "$(run "$dir/spec.cs" | jq -r .hookSpecificOutput.permissionDecision)"
check "silent on an unmarked file" "" "$(run "$dir/plain.cs")"
check "silent on a new file" "" "$(run "$dir/new.cs")"
check "silent on a new file named for approved examples" "" "$(run "$dir/NewApprovedExamples.cs")"
check "asks on a file named for approved examples" ask "$(run "$dir/CharmApprovedExamples.cs" | jq -r .hookSpecificOutput.permissionDecision)"
# A script that names an approved-examples file, run bare or wrapped.
printf 'sed -i s/a/b/ CharmApprovedExamples.cs\n' > "$dir/fix.sh"; chmod +x "$dir/fix.sh"
cp "$dir/fix.sh" "$dir/notes.txt"; chmod -x "$dir/notes.txt"
sh_run() { jq -n --arg c "$1" --arg d "$dir" '{tool_name: "Bash", tool_input: {command: $c}, cwd: $d}' | "$guard" | jq -r '.hookSpecificOutput.permissionDecision // empty'; }
check "asks on a script run through timeout and an interpreter" ask "$(sh_run 'timeout 60 bash fix.sh')"
check "asks on an executable script run through a wrapper" ask "$(sh_run 'systemd-run --user --scope timeout 300 ./fix.sh')"
check "silent on a plain file that names one, only read" "" "$(sh_run 'grep -n sed notes.txt')"
check "silent on an executable script named as an argument" "" "$(sh_run 'git show HEAD -- fix.sh')"
check "silent on an executable script read with cat" "" "$(sh_run 'cat fix.sh | head -3')"
check "asks on an executable script run through run0" ask "$(sh_run 'run0 ./fix.sh')"
check "asks on a script run as: timeout -s KILL 60 ./fix.sh" ask "$(sh_run 'timeout -s KILL 60 ./fix.sh')"
check "asks on a script run as: systemd-run --unit foo ./fix.sh" ask "$(sh_run 'systemd-run --unit foo ./fix.sh')"
check "asks on a script run as: systemd-run --user --scope ./fix.sh" ask "$(sh_run 'systemd-run --user --scope ./fix.sh')"
check "asks on a script run as: env FOO=1 ./fix.sh" ask "$(sh_run 'env FOO=1 ./fix.sh')"
check "asks on a script run as: FOO=1 ./fix.sh" ask "$(sh_run 'FOO=1 ./fix.sh')"
check "asks on a script run as: nice -n 5 ./fix.sh" ask "$(sh_run 'nice -n 5 ./fix.sh')"
check "asks on a script run as: sudo ./fix.sh" ask "$(sh_run 'sudo ./fix.sh')"
check "asks on a script run as: source fix.sh" ask "$(sh_run 'source fix.sh')"
check "asks on a script run as: . fix.sh" ask "$(sh_run '. fix.sh')"
check "asks on a script run as: python3 fix.sh" ask "$(sh_run 'python3 fix.sh')"
check "asks on a script run as: sudo -u bob ./fix.sh" ask "$(sh_run 'sudo -u bob ./fix.sh')"
check "asks on a script run as: nix develop -c ./fix.sh" ask "$(sh_run 'nix develop -c ./fix.sh')"
check "asks on a script run as: nix shell nixpkgs#jq --command ./fix.sh" ask "$(sh_run 'nix shell nixpkgs#jq --command ./fix.sh')"
check "asks on a script run as: cd . && ./fix.sh" ask "$(sh_run 'cd . && ./fix.sh')"
check "silent when only an argument names it: timeout -v; cat fix.sh" "" "$(sh_run 'timeout -v; cat fix.sh')"
check "silent when only an argument names it: sudo -E nice cat fix.sh" "" "$(sh_run 'sudo -E nice cat fix.sh')"
check "silent when only an argument names it: sudo -u bob git show HEAD -- fix.sh" "" "$(sh_run 'sudo -u bob git show HEAD -- fix.sh')"
exit $fail
