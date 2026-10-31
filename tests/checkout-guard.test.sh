#!/usr/bin/env bash
# The checkout guard's decisions the approved examples leave out: a session
# switching its own checkout, "git checkout -", and a checkout of a path.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
guard="$root/plugins/vicky-skills/scripts/checkout-guard.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
repo="$dir/repo"; data="$dir/data"
git init -q -b warp-b "$repo"
git -C "$repo" -c user.name=t -c user.email=t@example.invalid commit -q --allow-empty -m one
git -C "$repo" branch fix-x; printf 'readme\n' > "$repo/README.md"
fail=0
hook() { # session event command -> exit code
  jq -n --arg s "$1" --arg e "$2" --arg c "$3" --arg d "$repo" \
    '{session_id: $s, hook_event_name: $e, tool_name: "Bash", tool_input: {command: $c}, cwd: $d}' |
    CLAUDE_PLUGIN_OPTION_GUARD_CHECKOUT=true CLAUDE_PLUGIN_DATA="$data" bash "$guard" >/dev/null 2>&1
}
expect() { # name want session command
  hook "$3" PreToolUse "$4"; got=$?
  if [ "$got" = "$2" ]; then echo "ok   $1"; else echo "FAIL $1: exit $got, want $2"; fail=1; fi
}
hook A PostToolUse "git status"
expect "a session switching a checkout only it works in runs" 0 A "git switch fix-x"
expect "another session's git checkout - is refused" 2 B "git checkout -"
expect "another session's checkout of a path runs" 0 B "git checkout README.md"
expect "another session's checkout naming a path before a branch runs" 0 B "git checkout README.md fix-x"
expect "another session's switch is refused" 2 B "git switch fix-x"
expect "another session's checkout of a name that is neither a branch nor a path runs" 0 B "git checkout nosuchthing"
exit $fail
