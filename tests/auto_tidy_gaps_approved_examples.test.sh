#!/usr/bin/env bash
# shellcheck disable=SC2016 # check() evals its single-quoted condition later
# shellcheck disable=SC2034 # names set here are read inside check()'s eval
# Approved examples for the Auto-tidy gaps chart, T1 to T4: a merge inside a
# script tidies, detached and leftover worktrees go only when nothing is lost.
set -u
# shellcheck source=lib/auto-tidy-fixture.sh
. "$(dirname "$0")/lib/auto-tidy-fixture.sh"
# merge_call <command>: the PostToolUse payload of a Bash call, the way a REPL script's shell call reaches the hook.
merge_call() { jq -nc --arg c "$1" --arg d "$dir/repo" '{hook_event_name: "PostToolUse", tool_name: "Bash", tool_input: {command: $c}, cwd: $d}'; }
# detached <name> <commit>: a worktree on a detached HEAD at that commit.
detached() { git -C "$dir/repo" worktree add -q --detach "$dir/wt-$1" "$2" 2>/dev/null; }
# drop_doc: the repo's testing doc names its own removal script, which records each folder it removes.
drop_doc() {
  mkdir -p "$dir/repo/docs/agents" "$dir/repo/scripts"
  printf 'Drop worktree: scripts/drop.sh\n' > "$dir/repo/docs/agents/testing.md"
  printf '#!/usr/bin/env bash\necho "$1" >> "%s/dropped"\ngit worktree remove --force "$1" 2>/dev/null || rm -rf "$1"\n' "$dir" > "$dir/repo/scripts/drop.sh"
  chmod +x "$dir/repo/scripts/drop.sh"; rm -f "$dir/dropped"
}

# Given an agent that merges a pull request with tea or gh inside a REPL script
# When the script ends
# Then that pull request's branch and worktree are gone
# And the agent is told nothing about the tidy
for forge in gh tea; do
  FORGE=$forge
  setup; branch feat; worktree feat; on_main; merge feat keep
  out=$(run "$dir/repo" "$(merge_call "set -e
$forge pr merge 1 --squash")")
  check "T1 a merge run from a script with $forge tidies too" '[ ! -d "$dir/wt-feat" ] && ! has_local feat && agent_silent "$out"'
done
FORGE=gh

# Given an agent whose shell call runs `cd x` and then, on a new line, `gh pr merge 1`
# When the call ends
# Then that pull request's branch and worktree are gone
# And the agent is told nothing about the tidy
setup; branch feat; worktree feat; on_main; merge feat keep
out=$(run "$dir/repo" "$(merge_call "cd x
gh pr merge 1")")
check "X1 a merge on its own line tidies" '[ ! -d "$dir/wt-feat" ] && ! has_local feat && agent_silent "$out"'

# Given a worktree on a detached HEAD whose commit main already holds, with nothing uncommitted and no session in it
# When a session starts in the repo
# Then the worktree is gone
setup; on_main; detached d origin/main; main_moves
run >/dev/null
check "T2 a detached merged worktree goes" '[ ! -d "$dir/wt-d" ]'

# Given a worktree on a detached HEAD whose commit main does not hold
# When a session starts in the repo
# Then the worktree is still there
setup; on_main; detached d origin/main
echo solo > "$dir/wt-d/solo.txt"; git -C "$dir/wt-d" add solo.txt; git -C "$dir/wt-d" commit -q -m solo
run >/dev/null
check "T3 a detached worktree with unlanded work stays" '[ -d "$dir/wt-d" ] && [ -f "$dir/wt-d/solo.txt" ]'

# Given a worktree on a detached HEAD whose commit main already holds, with nothing uncommitted
# And it is locked, or a session works in it
# When a session starts in the repo
# Then the worktree is still there
setup; on_main; detached d origin/main; main_moves; git -C "$dir/repo" worktree lock "$dir/wt-d"
run >/dev/null
check "X2 a locked detached worktree stays" '[ -d "$dir/wt-d" ]'
setup; on_main; detached d origin/main; main_moves; busy "$dir/wt-d"
run >/dev/null
check "X2 a busy detached worktree stays" '[ -d "$dir/wt-d" ]'
reap

# Given a worktree on a detached HEAD whose commit main already holds, with uncommitted changes
# When a session starts in the repo
# Then the worktree is still there
setup; on_main; detached d origin/main; main_moves; echo half > "$dir/wt-d/notes.txt"
run >/dev/null
check "X3 a dirty detached worktree stays" '[ -f "$dir/wt-d/notes.txt" ]'

# Given a folder under .claude/worktrees that git no longer lists
# When a session starts in a repo whose testing doc names its own removal script
# Then that script removes the folder
setup; on_main; drop_doc; mkdir -p "$dir/repo/.claude/worktrees/old"; echo x > "$dir/repo/.claude/worktrees/old/left.txt"
run >/dev/null
check "T4 a leftover worktree folder goes" '[ ! -d "$dir/repo/.claude/worktrees/old" ] && grep -qx "$dir/repo/.claude/worktrees/old" "$dir/dropped"'

# Given a folder under .claude/worktrees that git no longer lists, with a session working in it
# When a session starts in a repo whose testing doc names its own removal script
# Then the folder is still there
setup; on_main; drop_doc; mkdir -p "$dir/repo/.claude/worktrees/old"; busy "$dir/repo/.claude/worktrees/old"
run >/dev/null
check "X4 a busy leftover folder stays" '[ -d "$dir/repo/.claude/worktrees/old" ]'
reap

# Given .claude/worktrees holding a worktree git lists and a folder git no longer lists
# When a session starts in a repo whose testing doc names its own removal script
# Then only the unlisted folder is gone
setup; on_main; drop_doc; branch live; git -C "$dir/repo" worktree add -q "$dir/repo/.claude/worktrees/live" live 2>/dev/null
mkdir -p "$dir/repo/.claude/worktrees/old"
run >/dev/null
check "X5 only unlisted folders go" '[ -d "$dir/repo/.claude/worktrees/live" ] && [ ! -d "$dir/repo/.claude/worktrees/old" ]'

exit "$fail"
