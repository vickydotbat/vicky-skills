#!/usr/bin/env bash
# approved-spec: the examples approved on the star "A session can't move a
# checkout another session works in". Each check is named after its example.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
guard="$root/plugins/vicky-skills/scripts/checkout-guard.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
repo="$dir/repo"; data="$dir/data"
git init -q -b warp-b "$repo"
git -C "$repo" -c user.name=t -c user.email=t@example.invalid commit -q --allow-empty -m one
git -C "$repo" branch fix-x
printf 'readme\n' > "$repo/README.md"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
# Runs the guard as session $1 for event $2 on command $3; leaves $code and $err.
hook() {
  err=$(jq -n --arg s "$1" --arg e "$2" --arg c "${3:-}" --arg d "$repo" \
    '{session_id: $s, hook_event_name: $e, tool_name: "Bash", tool_input: {command: $c}, cwd: $d}' |
    CLAUDE_PLUGIN_OPTION_GUARD_CHECKOUT="${ON-true}" CLAUDE_PLUGIN_DATA="$data" bash "$guard" 2>&1 >/dev/null); code=$?
}
# Session $1 runs a git command that the guard lets through, then it runs.
ran() { hook "$1" PreToolUse "$2"; [ $code = 0 ] || return 1; (cd "$repo" && eval "$2") >/dev/null 2>&1; hook "$1" PostToolUse "$2"; }
age() { python3 - "$data/checkouts/$1" "$2" <<'PY'
import sys, time
path, ago = sys.argv[1], int(sys.argv[2])
rows = [l.split("\t") for l in open(path).read().splitlines()]
open(path, "w").write("".join(f"{a}\t{b}\t{int(time.time()) - ago}\n" for a, b, _ in rows))
PY
}

ran A "git status"; age A 600
hook B PreToolUse "git checkout fix-x"; c1=$code; hook B PreToolUse "git checkout -b new-one"; c2=$code
hook B PreToolUse "git switch fix-x"
check "with session A on warp-b ten minutes ago, session B's git switch or git checkout to another branch is refused, names A's branch and says to use a worktree" \
  '[ $code = 2 ] && [ $c1 = 2 ] && [ $c2 = 2 ] && grep -q "warp-b" <<<"$err" && grep -q "git worktree add" <<<"$err" && [ "$(git -C "$repo" branch --show-current)" = warp-b ]'

hook B PreToolUse "git checkout warp-b -- README.md"
check "with session A working the checkout, session B's git checkout main -- README.md, a file restore on the same branch, runs" '[ $code = 0 ]'

hook A SessionEnd; hook B PreToolUse "git switch fix-x"; ended=$code
ran A "git status"; age A $((13 * 3600)); hook B PreToolUse "git switch fix-x"; stale=$code
check "once session A has ended, or its last git command there was over 12 hours ago, session B's branch switch runs" '[ $ended = 0 ] && [ $stale = 0 ]'

rm -rf "$data"; ran A "git status"; git -C "$repo" switch -q fix-x
hook A PreToolUse "git commit -m x"; first=$code; msg=$err
hook A PreToolUse "git status"; second=$code
check "when session A's checkout was switched from warp-b to fix-x since its last git command, A's next git command is refused once, names both branches and says to use a worktree for warp-b" \
  '[ $first = 2 ] && grep -q "warp-b" <<<"$msg" && grep -q "fix-x" <<<"$msg" && grep -q "git worktree add <dir> warp-b" <<<"$msg" && [ $second = 0 ]'
git -C "$repo" switch -q warp-b

rm -rf "$data"; ON=false ran A "git status"; ON=false hook B PreToolUse "git switch fix-x"; off=$code
check "with the checkout guard setting turned off, session B's switch of that checkout's branch runs" \
  '[ $off = 0 ] && [ ! -e "$data/checkouts" ]'

rm -rf "$data"; unset ON; ON= ran A "git status"; age A 600; ON= hook B PreToolUse "git switch fix-x"; fresh=$code
check "on a fresh install with no checkout guard setting, session B's switch of a checkout session A used ten minutes ago is refused" \
  '[ $fresh = 2 ] && jq -e ".userConfig.guard_checkout.default == true" "$root/plugins/vicky-skills/.claude-plugin/plugin.json" >/dev/null'
exit $fail
