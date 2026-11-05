#!/usr/bin/env bash
# approved-spec: the examples approved for "checkout-guard frees a checkout a
# session has left". Each check is named after its example.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
guard="$root/plugins/vicky-skills/scripts/checkout-guard.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
repo="$dir/repo"; wt="$dir/wt"; other="$dir/other"; data="$dir/data"
for r in "$repo" "$other"; do
  git init -q -b warp-b "$r"
  git -C "$r" config user.name t; git -C "$r" config user.email t@example.invalid
  git -C "$r" commit -q --allow-empty -m one
done
git -C "$repo" branch fix-x
git -C "$repo" worktree add -q -b wt-branch "$wt"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
# Runs the guard as session $1 for event $2 on command $3 inside folder $4;
# leaves $code and $err.
hook() {
  err=$(jq -n --arg s "$1" --arg e "$2" --arg c "$3" --arg d "$4" \
    '{session_id: $s, hook_event_name: $e, tool_name: "Bash", tool_input: {command: $c}, cwd: $d}' |
    CLAUDE_PLUGIN_OPTION_GUARD_CHECKOUT=true CLAUDE_PLUGIN_DATA="$data" bash "$guard" 2>&1 >/dev/null); code=$?
}
# Session $1 committed in folder $2, as the guard records it.
committed() { hook "$1" PostToolUse "git commit -q --allow-empty -m a" "$2"; }
# Move session $1's record line for folder $2 to $3 seconds ago.
age() { python3 - "$data/checkouts/$1" "$2" "$3" <<'PY'
import sys, time
path, folder, ago = sys.argv[1], sys.argv[2], int(sys.argv[3])
rows = [l.split("\t") for l in open(path).read().splitlines()]
open(path, "w").write("".join(
    f"{a}\t{b}\t{int(time.time()) - ago if a == folder else c}\n" for a, b, c in rows))
PY
}

# Given session A last ran a git command in the main checkout, and since then ran one in a worktree of the same repository
# When session B runs git switch to another branch in the main checkout
# Then the switch runs
rm -rf "$data"; committed A "$repo"; committed A "$wt"; age A "$repo" 600
hook B PreToolUse "git switch fix-x" "$repo"
check "with session A's last git command in the main checkout followed by one in a worktree of the same repository, session B's git switch in the main checkout runs" '[ $code = 0 ]'

# Given session A ran a git command in a worktree, then ran another in the main checkout
# When session B runs git switch to another branch in the main checkout
# Then it is refused, names A's branch and says to use a worktree
rm -rf "$data"; committed A "$wt"; age A "$wt" 600; committed A "$repo"
hook B PreToolUse "git switch fix-x" "$repo"
check "with session A back in the main checkout after a worktree, session B's git switch there is refused, names A's branch and says to use a worktree" \
  '[ $code = 2 ] && grep -q "warp-b" <<<"$err" && grep -q "git worktree add" <<<"$err"'

# Given session A ran a git command in the main checkout, and since then ran one in a different repository
# When session B runs git switch to another branch in the main checkout
# Then it is refused, names A's branch and says to use a worktree
rm -rf "$data"; committed A "$repo"; age A "$repo" 600; committed A "$other"
hook B PreToolUse "git switch fix-x" "$repo"
check "with session A's newer git command in a different repository, session B's git switch in the main checkout is refused, names A's branch and says to use a worktree" \
  '[ $code = 2 ] && grep -q "warp-b" <<<"$err" && grep -q "git worktree add" <<<"$err"'

# Given session A last ran a git command in the main checkout, and since then ran one in a worktree of the same repository
# When session B runs git commit in the main checkout
# Then the commit runs
rm -rf "$data"; committed A "$repo"; committed A "$wt"; age A "$repo" 600
hook B PreToolUse "git commit -q --allow-empty -m b" "$repo"
check "with session A's last git command in the main checkout followed by one in a worktree of the same repository, session B's git commit in the main checkout runs" '[ $code = 0 ]'
exit $fail
