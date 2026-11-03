#!/usr/bin/env bash
# approved-spec: the checkout-guard rebase examples, approved 2026-11-03. A
# real rebase stops on a conflict in a fixture repo, and the guard runs on
# the agent's next git command there.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
guard="$root/plugins/vicky-skills/scripts/checkout-guard.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
fail=0
g() { git -C "$1" -c user.name=t -c user.email=t@example.invalid "${@:2}"; }
hook() { # repo event command -> exit code
  jq -n --arg e "$2" --arg c "$3" --arg d "$1" \
    '{session_id: "A", hook_event_name: $e, tool_name: "Bash", tool_input: {command: $c}, cwd: $d}' |
    CLAUDE_PLUGIN_OPTION_GUARD_CHECKOUT=true CLAUDE_PLUGIN_DATA="$dir/data" bash "$guard" >/dev/null 2>&1
}
expect() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: exit $3, want $2"; fail=1; fi; }
# A repo on main whose rebase onto other stops on a conflict in one file.
fixture() {
  git init -q -b main "$1"
  printf 'one\n' > "$1/f"; g "$1" add f; g "$1" commit -q -m one
  g "$1" switch -q -c other; printf 'theirs\n' > "$1/f"; g "$1" commit -q -am theirs
  g "$1" switch -q main; printf 'mine\n' > "$1/f"; g "$1" commit -q -am mine
}

# Given a checkout on main, where you start a rebase that stops on a conflict
# When the agent runs a git command there to read the conflict
# Then checkout-guard lets it through, since the checkout is still on main
fixture "$dir/a"
hook "$dir/a" PostToolUse "git commit -am mine"
g "$dir/a" rebase -q other >/dev/null 2>&1
hook "$dir/a" PreToolUse "git diff --name-only --diff-filter=U"
expect "a rebase in progress keeps the checkout on its branch" 0 $?

# Given a checkout another session switched from main to another branch, with no rebase running
# When the agent runs a git command there
# Then checkout-guard still refuses it, and steers to a worktree
fixture "$dir/b"
hook "$dir/b" PostToolUse "git commit -am mine"
g "$dir/b" switch -q other
hook "$dir/b" PreToolUse "git status"
expect "a branch switched under the session is still refused" 2 $?
exit $fail
