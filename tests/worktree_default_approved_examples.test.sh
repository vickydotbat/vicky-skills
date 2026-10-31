#!/usr/bin/env bash
# approved-spec: the examples the user approved for working in a worktree by
# default: a checkout another session works sends history writes elsewhere.
# Each check is named after its example and runs the checkout guard.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
guard="$root/plugins/vicky-skills/scripts/checkout-guard.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
repo="$dir/repo"; data="$dir/data"
git init -q -b warp-b "$repo"
git -C "$repo" -c user.name=t -c user.email=t@example.invalid commit -q --allow-empty -m one
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
# Session $1 runs event $2 on command $3, with no setting given; leaves $code and $err.
hook() {
  err=$(jq -n --arg s "$1" --arg e "$2" --arg c "${3:-}" --arg d "$repo" \
    '{session_id: $s, hook_event_name: $e, tool_name: "Bash", tool_input: {command: $c}, cwd: $d}' |
    CLAUDE_PLUGIN_DATA="$data" bash "$guard" 2>&1 >/dev/null); code=$?
}
age() { python3 - "$data/checkouts/$1" "$2" <<'PY'
import sys, time
path, ago = sys.argv[1], int(sys.argv[2])
rows = [l.split("\t") for l in open(path).read().splitlines()]
open(path, "w").write("".join(f"{a}\t{b}\t{int(time.time()) - ago}\n" for a, b, _ in rows))
PY
}
hook A PostToolUse "git status"; age A 3600
refused=0
for c in "git commit -m x" "git rebase origin/main" "git reset --keep HEAD~1" "git merge fix" "git cherry-pick abc" "git stash" "git pull --rebase"; do
  hook B PreToolUse "$c"; [ $code = 2 ] && grep -q "worktree" <<<"$err" && refused=$((refused + 1)) || echo "     not refused: $c"
done
check "with session A in this checkout in the last 12 hours, session B's commit, rebase, reset, merge, cherry-pick, stash or pull there is refused and told to use its own worktree" '[ $refused = 7 ]'
read_ok=0
for c in "git status" "git log --oneline -3" "git diff"; do hook B PreToolUse "$c"; [ $code = 0 ] && read_ok=$((read_ok + 1)); done
check "with session A in this checkout an hour ago, session B's git status, git log or git diff runs" '[ $read_ok = 3 ]'
rm -rf "$data"; hook A PostToolUse "git status"; age A $((13 * 3600)); hook B PreToolUse "git commit -m x"
check "with no other session in this checkout in the last 12 hours, session B's commit runs" '[ $code = 0 ]'
exit $fail
