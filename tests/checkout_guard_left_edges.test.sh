#!/usr/bin/env bash
# Plain regression tests, no approved example behind them: what the checkout
# guard does at the edges of "a session that moved on no longer claims the
# checkout it left". The approved examples are in
# checkout_guard_left_approved_examples.test.sh.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
guard="$root/plugins/vicky-skills/scripts/checkout-guard.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
repo="$dir/repo"; wt="$dir/wt"; data="$dir/data"
git init -q -b warp-b "$repo"
git -C "$repo" config user.name t; git -C "$repo" config user.email t@example.invalid
git -C "$repo" commit -q --allow-empty -m one
git -C "$repo" branch fix-x
git -C "$repo" worktree add -q -b wt-branch "$wt"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
hook() { # session event command folder -> leaves $code
  jq -n --arg s "$1" --arg e "$2" --arg c "$3" --arg d "$4" \
    '{session_id: $s, hook_event_name: $e, tool_name: "Bash", tool_input: {command: $c}, cwd: $d}' |
    CLAUDE_PLUGIN_OPTION_GUARD_CHECKOUT=true CLAUDE_PLUGIN_DATA="$data" bash "$guard" >/dev/null 2>&1; code=$?
}
committed() { hook "$1" PostToolUse "git commit -q --allow-empty -m a" "$2"; }
age() { python3 - "$data/checkouts/$1" "$2" "$3" <<'PY'
import sys, time
path, folder, ago = sys.argv[1], sys.argv[2], int(sys.argv[3])
rows = [l.split("\t") for l in open(path).read().splitlines()]
open(path, "w").write("".join(
    f"{a}\t{b}\t{int(time.time()) - ago if a == folder else c}\n" for a, b, c in rows))
PY
}

# The worktree session A moved to is gone: its line points nowhere, so the
# guard cannot tell it belonged to this repository, and A keeps its claim.
rm -rf "$data"; committed A "$repo"; age A "$repo" 600; committed A "$wt"
git -C "$repo" worktree remove --force "$wt"
hook B PreToolUse "git switch fix-x" "$repo"
check "a session whose newer line points at a removed worktree keeps its claim on the checkout it left" '[ $code = 2 ]'
git -C "$repo" worktree add -q "$wt" wt-branch

# A left the worktree for the main checkout: B's commit in the worktree runs.
rm -rf "$data"; committed A "$wt"; age A "$wt" 600; committed A "$repo"
hook B PreToolUse "git commit -q --allow-empty -m b" "$wt"
check "a session that went from a worktree back to the main checkout no longer claims the worktree" '[ $code = 0 ]'
exit $fail
