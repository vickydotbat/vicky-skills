#!/usr/bin/env bash
# approved-spec: the examples approved on the note "LC-7 red-first-guard
# decides from state". The guard judges the files the commit holds.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
scripts="$root/plugins/vicky-skills/scripts"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
guard="$scripts/red-first-guard.sh"
fx=$(mktemp -d); trap 'rm -rf "$fx"' EXIT
setup() {
  rm -rf "$fx/r"; mkdir -p "$fx/r/dir with space" "$fx/r/tests"; cd "$fx/r" || exit 1
  git init -q; git config user.email t@t; git config user.name t
  echo a >a.sh; echo s >"dir with space/a.sh"; git add -A; git commit -qm init
}
run() { jq -nc --arg c "$1" --arg d "$fx/r" '{tool_name:"Bash",tool_input:{command:$c},cwd:$d}' | CLAUDE_PLUGIN_OPTION_GUARD_RED_FIRST=true bash "$guard" 2>&1 >/dev/null; echo "exit=$?"; }

# Given the agent staged only "dir with space/a.sh" with a quoted git add
# When it commits
# Then red-first-guard judges only that staged file
setup; echo t >tests/new_approved_examples.test.sh; echo s2 >"dir with space/a.sh"
check "LC-7 E1 a quoted path with a space counts only that file" 'run "git add \"dir with space/a.sh\" && git commit -m x" | grep -qx "exit=0"'

exit $fail
