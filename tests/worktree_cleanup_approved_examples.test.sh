#!/usr/bin/env bash
# approved-spec: the examples the user set for worktree cleanup on
# 2026-11-01: after the agent merges a branch checked out in a worktree, the
# worktree and its branch go once every commit has landed and nothing is
# uncommitted, and stay otherwise, with the agent told what is left. Each
# check runs the merge in the main clone, then the hook as Claude Code runs
# it after the command.
set -u
hook="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/worktree-place.sh"
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
export HOME="$scratch/home" CLAUDE_PLUGIN_OPTION_GUARD_WORKTREE_PLACE=true
mkdir -p "$HOME"
g() { git -c user.email=t@t -c user.name=t -c commit.gpgsign=false "$@"; }

# A repo on main, with <branch> checked out in .claude/worktrees/<branch>,
# two commits ahead. Prints the repo's path.
stage() {
  local repo="$scratch/$1"
  git init -q -b main "$repo"
  g -C "$repo" commit -q --allow-empty -m init
  printf 'one\n' >"$repo/shared.txt"
  g -C "$repo" add shared.txt
  g -C "$repo" commit -q -m shared
  git -C "$repo" worktree add -q -b "$1" "$repo/.claude/worktrees/$1"
  local wt="$repo/.claude/worktrees/$1"
  printf 'a\n' >"$wt/a.txt"; g -C "$wt" add a.txt; g -C "$wt" commit -q -m "first of $1"
  printf 'b\n' >"$wt/b.txt"; g -C "$wt" add b.txt; g -C "$wt" commit -q -m "second of $1"
  printf '%s' "$repo"
}
# Runs <command> in <repo>, then the hook after it. Prints what the hook told
# the agent.
merge() { # <repo> <command>
  (cd "$1" && bash -c "$2" >/dev/null 2>&1)
  jq -nc --arg c "$2" --arg d "$1" \
    '{hook_event_name: "PostToolUse", tool_name: "Bash", cwd: $d, session_id: "s1", tool_input: {command: $c}, tool_response: {stdout: ""}}' |
    bash "$hook" 2>&1
}
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

r=$(stage landed)
merge "$r" "git -c user.email=t@t -c user.name=t -c commit.gpgsign=false merge -q --no-edit landed" >/dev/null
check "C1: a clean worktree whose commits all landed goes, with its branch" \
  '[ ! -e "$r/.claude/worktrees/landed" ] && ! git -C "$r" rev-parse -q --verify refs/heads/landed >/dev/null'

r=$(stage squashed)
said=$(merge "$r" "git merge -q --squash squashed && git -c user.email=t@t -c user.name=t -c commit.gpgsign=false commit -q -m squashed")
check "C2: a worktree with commits still to land stays, and the agent is told which" \
  '[ -e "$r/.claude/worktrees/squashed/.git" ] && grep -q "first of squashed" <<<"$said" && grep -q "second of squashed" <<<"$said"'

r=$(stage dirty)
printf 'not yet\n' >"$r/.claude/worktrees/dirty/later.txt"
said=$(merge "$r" "git -c user.email=t@t -c user.name=t -c commit.gpgsign=false merge -q --no-edit dirty")
check "C3: a worktree with uncommitted changes stays, and the agent is told to commit or move them, then remove it" \
  '[ -e "$r/.claude/worktrees/dirty/later.txt" ] && grep -qi "uncommitted" <<<"$said" && grep -qi "remove" <<<"$said"'

r=$(stage clash)
printf 'two\n' >"$r/.claude/worktrees/clash/shared.txt"; g -C "$r/.claude/worktrees/clash" commit -qam "clash side"
printf 'three\n' >"$r/shared.txt"; g -C "$r" commit -qam "main side"
merge "$r" "git -c user.email=t@t -c user.name=t -c commit.gpgsign=false merge -q --no-edit clash" >/dev/null
check "C4: a merge that stops on a conflict removes nothing" \
  '[ -e "$r/.claude/worktrees/clash/.git" ] && git -C "$r" rev-parse -q --verify refs/heads/clash >/dev/null'
exit $fail
