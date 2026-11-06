#!/usr/bin/env bash
# approved-spec: the examples the user set for a repo's own worktree drop
# script on 2026-11-06 (W1 to W3; W4 and W5 are over-to-you skill text, backed
# by an eval case). A repo names its script on a "Drop worktree: <path>" line of
# docs/agents/testing.md. The worktree guard then names that script, and runs
# it for a landed branch, in place of git worktree remove. Each check runs the
# merge in the main clone, then the hook as Claude Code runs it after the command.
set -u
hook="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/worktree-place.sh"
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
export HOME="$scratch/home" CLAUDE_PLUGIN_OPTION_GUARD_WORKTREE_PLACE=true
mkdir -p "$HOME"
g() { git -c user.email=t@t -c user.name=t -c commit.gpgsign=false "$@"; }

# A repo on main with <branch> in .claude/worktrees/<branch>, one commit ahead.
# $2 is "drop" to give the repo a drop script and its docs line, "fail" for a
# script that refuses, anything else for neither. Prints the repo's path.
stage() { # <branch> <mode>
  local repo="$scratch/$1"
  git init -q -b main "$repo"
  g -C "$repo" commit -q --allow-empty -m init
  case "$2" in
    drop | fail)
      mkdir -p "$repo/docs/agents" "$repo/scripts"
      printf 'Drop worktree: scripts/drop.sh\n' >"$repo/docs/agents/testing.md"
      if [ "$2" = drop ]; then
        printf '#!/usr/bin/env bash\necho "$1" >"%s/dropped"\ngit worktree remove --force "$1"\n' "$scratch" >"$repo/scripts/drop.sh"
      else
        printf '#!/usr/bin/env bash\necho "a container still mounts it" >&2\nexit 1\n' >"$repo/scripts/drop.sh"
      fi
      chmod +x "$repo/scripts/drop.sh"
      ;;
  esac
  git -C "$repo" worktree add -q -b "$1" "$repo/.claude/worktrees/$1"
  local wt="$repo/.claude/worktrees/$1"
  printf 'a\n' >"$wt/a.txt"; g -C "$wt" add a.txt; g -C "$wt" commit -q -m "first of $1"
  printf '%s' "$repo"
}
merge() { # <repo> <branch>
  local cmd="git -c user.email=t@t -c user.name=t -c commit.gpgsign=false merge -q --no-edit $2"
  (cd "$1" && bash -c "$cmd" >/dev/null 2>&1)
  jq -nc --arg c "$cmd" --arg d "$1" \
    '{hook_event_name: "PostToolUse", tool_name: "Bash", cwd: $d, session_id: "s1", tool_input: {command: $c}, tool_response: {stdout: ""}}' |
    bash "$hook" 2>&1
}
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

# Given a repo whose testing doc has a "Drop worktree:" line
# When the worktree guard tells the user a worktree must go
# Then the message names that command, and not git worktree remove
r=$(stage w1 drop)
printf 'not yet\n' >"$r/.claude/worktrees/w1/later.txt"
said=$(merge "$r" w1)
check "W1: a worktree that must go is removed with the repo's drop script" \
  'grep -q "scripts/drop.sh" <<<"$said" && ! grep -q "git worktree remove" <<<"$said"'

# Given a repo whose testing doc has no "Drop worktree:" line
# When the worktree guard tells the user a worktree must go
# Then the message names git worktree remove and git branch -d, as it does now
r=$(stage w2 none)
printf 'not yet\n' >"$r/.claude/worktrees/w2/later.txt"
said=$(merge "$r" w2)
check "W2: with no drop script the message names git worktree remove and git branch -d" \
  'grep -q "git worktree remove" <<<"$said" && grep -q "git branch -d" <<<"$said"'

# Given a repo with a "Drop worktree:" line and a merged branch whose worktree is clean
# When the guard removes that worktree itself
# Then it runs the drop command for it, and not git worktree remove
r=$(stage w3 drop)
merge "$r" w3 >/dev/null
check "W3: a landed clean worktree is removed by the drop script, and its branch goes" \
  '[ "$(cat "$scratch/dropped" 2>/dev/null)" = "$r/.claude/worktrees/w3" ] && [ ! -e "$r/.claude/worktrees/w3" ] && ! git -C "$r" rev-parse -q --verify refs/heads/w3 >/dev/null'

# Open point of W3: a drop script that fails leaves the worktree and branch, and the message says why.
r=$(stage w3b fail)
said=$(merge "$r" w3b)
check "W3b: a drop script that refuses leaves the worktree and branch, and the message says why" \
  '[ -e "$r/.claude/worktrees/w3b/.git" ] && git -C "$r" rev-parse -q --verify refs/heads/w3b >/dev/null && grep -q "container still mounts" <<<"$said"'
exit $fail
