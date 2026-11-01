#!/usr/bin/env bash
# worktree-place's decisions beyond its approved examples: every way a
# command names its repo and its path, the ignore line, and every merge that
# must leave a worktree alone.
set -u
hook="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/worktree-place.sh"
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
export HOME="$scratch/home" CLAUDE_PLUGIN_OPTION_GUARD_WORKTREE_PLACE=true
mkdir -p "$HOME"
g() { git -c user.email=t@t -c user.name=t -c commit.gpgsign=false "$@"; }
repo="$scratch/repo"
git init -q -b main "$repo"
g -C "$repo" commit -q --allow-empty -m init
fail=0

# The hook's exit status for a command, from <cwd>, at <event>.
hook_on() { # <command> [cwd] [event]
  jq -nc --arg c "$1" --arg d "${2:-$repo}" --arg e "${3:-PreToolUse}" \
    '{hook_event_name: $e, tool_name: "Bash", cwd: $d, session_id: "s1", tool_input: {command: $c}}' |
    bash "$hook" >"$scratch/said" 2>&1
  echo $?
}
expect() { # <name> <want> <command> [cwd] [event]
  local got
  got=$(hook_on "$3" "${4:-}" "${5:-}")
  if [ "$got" = "$2" ]; then echo "ok   $1"; else echo "FAIL $1: exit $got, want $2"; fail=1; fi
}
yes() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

expect "a path outside is refused" 2 "git worktree add ../out"
yes "the steer names the branch given with -b" 'expect x 2 "git worktree add -b topic ../out" >/dev/null; grep -qF ".claude/worktrees/topic" "$scratch/said"'
yes "the steer names the branch given with -B" 'expect x 2 "git worktree add -B topic2 ../out" >/dev/null; grep -qF ".claude/worktrees/topic2" "$scratch/said"'
yes "without a branch flag, the steer names the folder" 'expect x 2 "git worktree add ../plain" >/dev/null; grep -qF ".claude/worktrees/plain" "$scratch/said"'
yes "a --reason value is no path" 'expect x 2 "git worktree add --lock --reason why ../locked" >/dev/null; grep -qF ".claude/worktrees/locked" "$scratch/said"'
expect "an option without a value is skipped" 2 "git worktree add --detach ../out HEAD"
expect "a path under ~ outside is refused" 2 "git worktree add ~/elsewhere"
HOME="$scratch" expect "a path under ~ inside the folder passes" 0 "git worktree add ~/repo/.claude/worktrees/tilde"
expect "an add with no path is left to git" 0 "git worktree add --detach"
expect "an absolute path inside .claude/worktrees passes" 0 "git worktree add $repo/.claude/worktrees/abs"
expect "a path that climbs out of .claude/worktrees is refused" 2 "git worktree add .claude/worktrees/../../out"
expect "the folder itself is no worktree's place" 2 "git worktree add .claude/worktrees"
expect "git -C names the repo, and the path is read from there" 0 "git -C $repo worktree add .claude/worktrees/viaC" "$scratch"
expect "a leading cd names the repo" 2 "cd $repo && git worktree add ../out" "$scratch"
expect "a git option before worktree is read" 2 "git -c core.x=1 worktree add ../out"
expect "a later segment is checked too" 2 "echo hi; git worktree add ../out"
expect "worktree list passes" 0 "git worktree list"
expect "a command with no git passes" 0 "ls ../out"
expect "outside a repository nothing is checked" 0 "git worktree add ../out" "$scratch"
CLAUDE_PLUGIN_OPTION_GUARD_WORKTREE_PLACE= expect "the option off passes" 0 "git worktree add ../out"
CLAUDE_PLUGIN_OPTION_GUARD_WORKTREE_PLACE=false expect "the option at false passes" 0 "git worktree add ../out"
CLAUDE_PLUGIN_OPTION_GUARD_WORKTREE_PLACE=1 expect "the option at 1 refuses" 2 "git worktree add ../out"
expect "after the command, an add is not judged again" 0 "git worktree add ../out" "" PostToolUse

# The ignore line: written once, and only when git doesn't already ignore it.
exclude="$repo/.git/info/exclude"
hook_on "git worktree add .claude/worktrees/one" >/dev/null
hook_on "git worktree add .claude/worktrees/two" >/dev/null
yes "the ignore line is written once" '[ "$(grep -cx ".claude/worktrees/" "$exclude")" = 1 ]'
other="$scratch/other"
git init -q -b main "$other"
printf '.claude/\n' >"$other/.gitignore"
hook_on "git worktree add .claude/worktrees/one" "$other" >/dev/null
yes "a repo that already ignores the folder gets no line" '! grep -qx ".claude/worktrees/" "$other/.git/info/exclude" 2>/dev/null'
bare="$scratch/bare"
git init -q -b main "$bare"
rm -rf "$bare/.git/info"
hook_on "git worktree add .claude/worktrees/one" "$bare" >/dev/null
yes "a repo with no info folder gets one" 'grep -qx ".claude/worktrees/" "$bare/.git/info/exclude"'

# Merges that must leave a worktree alone.
git -C "$repo" worktree add -q -b both "$repo/.claude/worktrees/both"
g -C "$repo/.claude/worktrees/both" commit -q --allow-empty -m "both ahead"
printf x >"$repo/.claude/worktrees/both/dirty.txt"
hook_on "git merge both" "" PostToolUse >/dev/null
yes "a worktree both dirty and ahead gets one message, about the changes" \
  '[ "$(jq -s length "$scratch/said")" = 1 ] && grep -q uncommitted "$scratch/said"'
touch "$repo/.git/MERGE_HEAD"
hook_on "git merge both" "" PostToolUse >/dev/null
yes "while a merge is still in progress nothing is said" '[ ! -s "$scratch/said" ]'
rm "$repo/.git/MERGE_HEAD"
git -C "$repo" worktree add -q -b side "$repo/.claude/worktrees/side"
g -C "$repo/.claude/worktrees/side" commit -q --allow-empty -m side
wt="$repo/.claude/worktrees/side"
g -C "$repo" merge -q --no-edit side
expect "before the command, a merge cleans nothing" 0 "git merge side" "" PreToolUse
yes "so the worktree is still there" '[ -e "$wt/.git" ]'
hook_on "git merge --no-edit -m done main" "$wt" PostToolUse >/dev/null
yes "merging the main clone's branch from a worktree never removes the main clone" '[ -e "$repo/.git" ] && [ -e "$wt/.git" ]'
git -C "$repo" branch loose
printf x >"$repo/stray.txt"
hook_on "git merge nosuch loose" "" PostToolUse >/dev/null
yes "a branch with no worktree is left alone, and nothing is said" '[ -e "$wt/.git" ] && [ ! -s "$scratch/said" ]'
rm "$repo/stray.txt"
hook_on "git merge -s ort -X ours side" "" PostToolUse >/dev/null
yes "option values are skipped, and the branch after them is cleaned" '[ ! -e "$wt" ] && ! git -C "$repo" rev-parse -q --verify refs/heads/side >/dev/null'
git -C "$repo" worktree add -q -b tell "$repo/.claude/worktrees/tell"
g -C "$repo/.claude/worktrees/tell" commit -q --allow-empty -m tell
g -C "$repo" merge -q --no-edit tell
said=$(jq -nc --arg d "$repo" '{hook_event_name: "PostToolUse", tool_name: "Bash", cwd: $d, tool_input: {command: "git merge tell"}}' | bash "$hook" 2>/dev/null)
yes "the agent is told what was removed" 'jq -e ".hookSpecificOutput.hookEventName == \"PostToolUse\"" <<<"$said" >/dev/null && grep -q "removed" <<<"$said"'
exit $fail
