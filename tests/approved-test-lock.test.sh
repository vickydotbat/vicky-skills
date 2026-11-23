#!/usr/bin/env bash
# shellcheck disable=SC2016 # check() evals its single-quoted condition later
# shellcheck disable=SC2034 # names set here are read inside check()'s eval
# shellcheck disable=SC2329 # helpers are called inside check()'s eval
# approved-test-lock's decisions beyond its approved examples: an edit that
# keeps every step line, a new approved file main lacks, an unticked record, a
# record for another test, MultiEdit, the setting off, a missing jq and bad input.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
hook="$root/plugins/vicky-skills/scripts/approved-test-lock.sh"
fx=$(mktemp -d); trap 'rm -rf "$fx"' EXIT
repo="$fx/repo"; mkdir -p "$repo/tests" "$repo/docs"
git -C "$repo" init -q -b main; git -C "$repo" config user.email t@t; git -C "$repo" config user.name t
printf '# Given a thing\n# When it runs\n# Then it works\ncheck x\n' >"$repo/tests/foo_approved_examples.test.sh"
printf '# approved-spec: x\n# Given a tag\n# Then it counts\n' >"$repo/tests/tagged.test.sh"
git -C "$repo" add -A; git -C "$repo" commit -qm init; git -C "$repo" switch -qc work
f="$repo/tests/foo_approved_examples.test.sh"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
rc() { jq -nc --arg d "$repo" "$1" | CLAUDE_PLUGIN_OPTION_GUARD_APPROVED_TEST_LOCK="${opt-}" bash "$hook" >/dev/null 2>&1; echo $?; }
edit() { rc "{tool_name:\"Edit\",cwd:\$d,tool_input:{file_path:\"$1\",old_string:\"$2\",new_string:\"$3\"}}"; }

check "an edit that keeps every step line goes through" '[ "$(edit "$f" "check x" "check y")" = 0 ]'
check "an Edit with replace_all that drops a repeated step line is refused" '[ "$(cp "$f" "$fx/keep"; printf "# Then it works\n" >>"$f"; r=$(rc "{tool_name:\"Edit\",cwd:\$d,tool_input:{file_path:\"$f\",old_string:\"# Then it works\",new_string:\"# Then no\",replace_all:true}}"); cp "$fx/keep" "$f"; echo "$r")" = 2 ]'
check "a relative path is read from the folder" '[ "$(edit tests/foo_approved_examples.test.sh "# Then it works" "# Then no")" = 2 ]'
check "a MultiEdit that drops a step line is refused" '[ "$(rc "{tool_name:\"MultiEdit\",cwd:\$d,tool_input:{file_path:\"$f\",edits:[{old_string:\"# When it runs\",new_string:\"\"}]}}")" = 2 ]'
check "a MultiEdit that keeps them goes through" '[ "$(rc "{tool_name:\"MultiEdit\",cwd:\$d,tool_input:{file_path:\"$f\",edits:[{old_string:\"check x\",new_string:\"check z\"}]}}")" = 0 ]'
printf '# Given new\n' >"$repo/tests/new_approved_examples.test.sh"
check "a new approved file main lacks goes through" '[ "$(edit "$repo/tests/new_approved_examples.test.sh" "# Given new" "# Given newer")" = 0 ]'
check "a shell write to a plain file goes through" '[ "$(rc "{tool_name:\"Bash\",cwd:\$d,tool_input:{command:\"echo x > notes.txt\"}}")" = 0 ]'
bash_rc() { rc "{tool_name:\"Bash\",cwd:\$d,tool_input:{command:\"$1\"}}"; }
check "a glob that names an approved test is refused" '[ "$(bash_rc "rm tests/*approved_examples*")" = 2 ]'
check "a prefix glob that names an approved test is refused" '[ "$(bash_rc "rm tests/foo_approved_exam*")" = 2 ]'
check "a tagged approved test named otherwise is refused" '[ "$(bash_rc "rm tests/tagged.test.sh")" = 2 ]'
check "a glob that names no approved test goes through" '[ "$(bash_rc "rm tests/*.txt")" = 0 ]'
check "running an approved test with its output redirected goes through" '[ "$(bash_rc "bash tests/foo_approved_examples.test.sh 2>&1 | tail")" = 0 ]'
check "listing tests into /dev/null goes through" '[ "$(bash_rc "ls tests/* >/dev/null")" = 0 ]'
check "copying an approved test elsewhere goes through" '[ "$(bash_rc "cat tests/tagged.test.sh > $fx/x")" = 0 ]'
post() { jq -nc --arg d "$repo" '{hook_event_name:"PostToolUse",tool_name:"Bash",cwd:$d,tool_input:{command:"x"}}' | bash "$hook" >/dev/null 2>&1; echo $?; }
cp "$f" "$fx/keep"
check "a write the pre-check cannot read is reverted after it runs" '[ "$(sed -i "s/# Then it works/# Then no/" "$f"; post)" = 2 ] && cmp -s "$f" "$fx/keep"'
check "a deleted approved test is restored after the command" '[ "$(rm "$f"; post)" = 2 ] && cmp -s "$f" "$fx/keep"'
check "a quoted rm target is refused" '[ "$(bash_rc "rm \\\"tests/foo_approved_examples.test.sh\\\"")" = 2 ]'
check "a command that only prints rm and an approved test goes through" '[ "$(bash_rc "echo rm tests/foo_approved_examples.test.sh")" = 0 ]'
check "git rm of an approved test is refused" '[ "$(bash_rc "git rm tests/foo_approved_examples.test.sh")" = 2 ]'
check "a Write that keeps every step line goes through" '[ "$(rc "{tool_name:\"Write\",cwd:\$d,tool_input:{file_path:\"$f\",content:\"# Given a thing\\n# When it runs\\n# Then it works\\nnew\\n\"}}")" = 0 ]'
check "a command that keeps every step line is left alone" '[ "$(printf "check more\n" >>"$f"; post)" = 0 ] && grep -q "check more" "$f"'
cp "$fx/keep" "$f"
check "a MultiEdit entry with replace_all that drops a repeated step line is refused" '[ "$(printf "# Then it works\n" >>"$f"; r=$(rc "{tool_name:\"MultiEdit\",cwd:\$d,tool_input:{file_path:\"$f\",edits:[{old_string:\"# Then it works\",new_string:\"# Then no\",replace_all:true}]}}"); cp "$fx/keep" "$f"; echo "$r")" = 2 ]'
check "a path through .. is locked too" '[ "$(edit "$repo/tests/../tests/foo_approved_examples.test.sh" "# Then it works" "# Then no")" = 2 ]'
check "a path with a double slash is locked too" '[ "$(edit "$repo/tests//foo_approved_examples.test.sh" "# Then it works" "# Then no")" = 2 ]'
check "a relative path is read from the hook's folder" '[ "$(jq -nc --arg d "$repo/tests" "{tool_name:\"Edit\",cwd:\$d,tool_input:{file_path:\"foo_approved_examples.test.sh\",old_string:\"# Then it works\",new_string:\"# Then no\"}}" | bash "$hook" >/dev/null 2>&1; echo $?)" = 2 ]'
check "reading an approved test goes through" '[ "$(rc "{tool_name:\"Bash\",cwd:\$d,tool_input:{command:\"cat $f\"}}")" = 0 ]'
printf 'tests/foo_approved_examples.test.sh:3\n- [ ] approve\n' >"$repo/docs/a.md"; git -C "$repo" add -A; git -C "$repo" commit -qm a
check "an unticked record keeps the lock" '[ "$(edit "$f" "# Then it works" "# Then no")" = 2 ]'
printf 'tests/other_approved_examples.test.sh:3\n- [x] approve\n' >"$repo/docs/a.md"; git -C "$repo" commit -qam b
check "a record for another test keeps the lock" '[ "$(edit "$f" "# Then it works" "# Then no")" = 2 ]'
check "a missing folder goes through" '[ "$(jq -nc --arg d "$fx/none" "{tool_name:\"Edit\",cwd:\$d,tool_input:{file_path:\"$f\",old_string:\"# Then it works\",new_string:\"\"}}" | bash "$hook" >/dev/null 2>&1; echo $?)" = 0 ]'
printf '# Given plain\nx\n' >"$repo/tests/p.test.sh"; printf 'echo x\n' >"$repo/tests/bare_approved_examples.test.sh"
git -C "$repo" switch -q main; git -C "$repo" add tests/p.test.sh tests/bare_approved_examples.test.sh
mkdir -p "$repo/docs"; printf 'tests/foo_approved_examples.test.sh:3\n- [x] approve\n' >"$repo/docs/old.md"; git -C "$repo" add docs/old.md; git -C "$repo" commit -qm main2
git -C "$repo" switch -q work; git -C "$repo" rebase -q main
check "a record already on main keeps the lock" '[ "$(edit "$f" "# Then it works" "# Then no")" = 2 ]'
printf '\ntests/foo_approved_examples.test.sh:2\n- [x] approve\n' >>"$repo/docs/old.md"; git -C "$repo" commit -qam add-to-old
check "a record a branch adds to a file main holds counts" '[ "$(edit "$f" "# When it runs" "# When no")" = 0 ]'
check "a shell change to a plain test on main is left alone" '[ "$(sed -i "/# Given plain/d" "$repo/tests/p.test.sh"; post)" = 0 ] && ! grep -q "Given plain" "$repo/tests/p.test.sh"'
git -C "$repo" checkout -q -- tests/p.test.sh
check "a deleted plain test stays deleted" '[ "$(rm "$repo/tests/p.test.sh"; post)" = 0 ] && [ ! -e "$repo/tests/p.test.sh" ]'
git -C "$repo" checkout -q -- tests/p.test.sh
check "a deleted approved test with its record stays deleted" '[ "$(rm "$f"; post)" = 0 ] && [ ! -e "$f" ]'
git -C "$repo" checkout -q -- "$f"
check "a plain test on main may drop a step-shaped line" '[ "$(edit "$repo/tests/p.test.sh" "# Given plain" "")" = 0 ]'
check "an approved file with no step lines may be edited" '[ "$(edit "$repo/tests/bare_approved_examples.test.sh" "echo x" "echo y")" = 0 ]'
check "deleting a new approved file main lacks goes through" '[ "$(rc "{tool_name:\"Bash\",cwd:\$d,tool_input:{command:\"rm tests/new_approved_examples.test.sh\"}}")" = 0 ]'
git -C "$repo" switch -q main; printf '# Given late\n# Then it lands\n' >"$repo/tests/late_approved_examples.test.sh"; git -C "$repo" add -A; git -C "$repo" commit -qm late; git -C "$repo" switch -q work
late="$repo/tests/late_approved_examples.test.sh"
check "an approved test only main holds stays out of a branch behind it" '[ "$(post)" = 0 ] && [ ! -e "$late" ]'
check "removing a copy of a test only main holds goes through" '[ "$(git -C "$repo" show main:tests/late_approved_examples.test.sh >"$late"; bash_rc "rm tests/late_approved_examples.test.sh")" = 0 ]'
rm -f "$late"
k="$repo/tests/keep_approved_examples.test.sh"
git -C "$repo" switch -q main; printf '# Given kept\n# Then it holds\n' >"$k"; git -C "$repo" add -A; git -C "$repo" commit -qm keep; git -C "$repo" switch -q work; git -C "$repo" rebase -q main
git -C "$repo" switch -q main; sed -i 's/# Then it holds/# Then it holds fast/' "$k"; git -C "$repo" commit -qam steps; git -C "$repo" switch -q work
check "a branch's older copy of a test main changed is left as it was" '[ "$(post)" = 0 ] && grep -qx "# Then it holds" "$k"'
check "a branch's own change to its older copy is still put back" '[ "$(sed -i "/# Given kept/d" "$k"; post)" = 2 ] && grep -qx "# Given kept" "$k" && grep -qx "# Then it holds" "$k"'
git -C "$repo" checkout -q -- tests; git -C "$repo" switch -q main; printf '# Given dropped\n' >"$repo/tests/drop_approved_examples.test.sh"; git -C "$repo" add tests/drop_approved_examples.test.sh; git -C "$repo" commit -qm add-drop
git -C "$repo" switch -q work; git -C "$repo" rebase -q main; git -C "$repo" switch -q main; git -C "$repo" rm -q tests/drop_approved_examples.test.sh; git -C "$repo" commit -qm drop; git -C "$repo" switch -q work
check "a test main dropped after the fork is no longer locked" '[ -f "$repo/tests/drop_approved_examples.test.sh" ] && [ "$(bash_rc "rm tests/drop_approved_examples.test.sh")" = 0 ]'
check "another tool goes through" '[ "$(rc "{tool_name:\"Read\",cwd:\$d,tool_input:{file_path:\"$f\"}}")" = 0 ]'
check "outside git goes through" '[ "$(jq -nc --arg d "$fx" "{tool_name:\"Edit\",cwd:\$d,tool_input:{file_path:\"$f\"}}" | bash "$hook" >/dev/null 2>&1; echo $?)" = 0 ]'
check "the setting off goes through" '[ "$(opt=false edit "$f" "# Then it works" "# Then no")" = 0 ]'
check "bad input goes through" '[ "$(echo notjson | bash "$hook" >/dev/null 2>&1; echo $?)" = 0 ]'
check "no jq goes through" '[ "$(echo "{}" | PATH=/nonexistent "$BASH" "$hook" >/dev/null 2>&1; echo $?)" = 0 ]'
exit $fail
