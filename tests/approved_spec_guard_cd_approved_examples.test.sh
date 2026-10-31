#!/usr/bin/env bash
# approved-spec: the examples approved on the ticket "approved-spec guard
# follows a leading cd into a worktree". The guard reads a command's files
# from the folder a leading cd moves to, such as a worktree.
set -u
guard="$(dirname "$0")/../plugins/vicky-skills/scripts/approved-spec-guard.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
test=tests/charm_approved_examples.test.sh
# tree: a worktree outside the session's folder. granted: a worktree whose
# git folder lists the test in its grants. session: the session's folder,
# holding a test of the same name that no one granted. empty: a session
# folder without the test.
mkdir -p "$dir/tree/tests" "$dir/granted/tests" "$dir/session/tests" "$dir/empty"
for d in tree granted session; do printf 'echo ok\n' > "$dir/$d/$test"; done
for d in tree granted session; do git init -q "$dir/$d"; done
echo "$test" > "$(git -C "$dir/granted" rev-parse --absolute-git-dir)/approved-spec-grants"
fail=0
run() { jq -n --arg c "$2" --arg d "$dir/$1" '{tool_name: "Bash", tool_input: {command: $c}, cwd: $d}' | bash "$guard" | jq -r '.hookSpecificOutput.permissionDecision // empty'; }
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got '$3', want '$2'"; fail=1; fi; }

check "given an approved test in a worktree, when a command that starts with cd into that worktree edits the test, the guard refuses it" \
  deny "$(run empty "cd $dir/tree && sed -i s/ok/no/ $test")"
check "given an approved test in a worktree, when a command that starts with cd into the worktree's path in quotes edits the test, the guard refuses it" \
  deny "$(run empty "cd \"$dir/tree\" && sed -i s/ok/no/ $test")"
check "given an approved test in a worktree, when a command that starts with cd into that worktree only runs the test, the guard lets it through" \
  "" "$(run session "cd $dir/tree && bash $test")"
check "given a cd into a folder that doesn't exist, when the command edits a file by an approved test's name, the guard looks in the session's folder" \
  deny "$(run session "cd $dir/nowhere && sed -i s/ok/no/ $test")"
check "given my yes in a draft opened in a worktree, when a command that starts with cd into that worktree edits the test, the guard lets it through" \
  "" "$(run session "cd $dir/granted && sed -i s/ok/no/ $test")"
exit $fail
