#!/usr/bin/env bash
# approved-spec: the examples the user set for worktree placement on
# 2026-11-01: every worktree an agent adds lives in the repo's own
# .claude/worktrees folder, the main clone never lists it, and no refusal
# hands the user a command. Each check runs the hook the way Claude Code
# does, then runs the command when the hook lets it through.
set -u
hook="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/worktree-place.sh"
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
export HOME="$scratch/home" CLAUDE_PLUGIN_OPTION_GUARD_WORKTREE_PLACE=true
mkdir -p "$HOME" "$scratch/projects"
repo="$scratch/projects/repo"
git init -q -b main "$repo"
git -C "$repo" -c user.email=t@t -c user.name=t -c commit.gpgsign=false commit -q --allow-empty -m init
printf 'build/\n' >"$repo/.gitignore"
git -C "$repo" add .gitignore
git -C "$repo" -c user.email=t@t -c user.name=t -c commit.gpgsign=false commit -q -m ignore

# Runs the hook on a command from the repo, then the command itself when the
# hook let it through. Prints the hook's exit status, then what it said.
try() {
  local out status
  out=$(jq -nc --arg c "$1" --arg d "$repo" \
    '{hook_event_name: "PreToolUse", tool_name: "Bash", cwd: $d, session_id: "s1", tool_input: {command: $c}}' |
    bash "$hook" 2>&1)
  status=$?
  [ "$status" = 0 ] && (cd "$repo" && bash -c "$1" >/dev/null 2>&1)
  printf '%s\n%s' "$status" "$out"
}
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

r1=$(try "git worktree add -q -b feature ../repo-feature")
check "W1: a worktree beside the repo is refused, and the refusal names .claude/worktrees/<branch> inside the repo" \
  '[ "$(head -1 <<<"$r1")" = 2 ] && [ ! -e "$scratch/projects/repo-feature" ] && grep -qF ".claude/worktrees/feature" <<<"$r1"'

r2=$(try "git worktree add -q -b other $scratch/projects/.worktrees/other")
check "W2: a worktree in any other folder is refused, with the same steer" \
  '[ "$(head -1 <<<"$r2")" = 2 ] && [ ! -e "$scratch/projects/.worktrees/other" ] && grep -qF ".claude/worktrees/other" <<<"$r2"'

r3=$(try "git worktree add -q -b feature .claude/worktrees/feature")
check "W3: a worktree at .claude/worktrees/feature is made" \
  '[ "$(head -1 <<<"$r3")" = 0 ] && [ -e "$repo/.claude/worktrees/feature/.git" ]'

check "W4: git status in the main clone does not list the worktree, and no tracked file changed" \
  '[ -e "$repo/.claude/worktrees/feature/.git" ] && [ -z "$(git -C "$repo" status --porcelain)" ]'

check "W5: no refusal names a file or command for the user to run" \
  'out=$(printf "%s\n" "$r1" "$r2"); [ -n "$out" ] && ! grep -qiE "in (your|their) own terminal|ask the user to (run|create)|touch " <<<"$out"'
exit $fail
