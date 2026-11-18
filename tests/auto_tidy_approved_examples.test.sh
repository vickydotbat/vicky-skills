#!/usr/bin/env bash
# Approved examples for HB-7: auto-tidy does all of the cleanup itself, at
# session start and after a merge, and tells the agent nothing.
set -u
. "$(dirname "$0")/lib/auto-tidy-fixture.sh"

# Given a local branch whose pull request merged
# When a session starts in the repo
# Then the branch is gone
setup; branch feat; merge feat; on_main
run >/dev/null
check "T1 a merged branch goes" '! has_local feat'


# Given a worktree whose branch merged, with nothing uncommitted and no session working in it
# When a session starts in the repo
# Then the worktree and its branch are gone
setup; branch feat; worktree feat; merge feat; on_main
run >/dev/null
check "T3 a merged worktree goes" '[ ! -d "$dir/wt-feat" ] && ! has_local feat'


# Given a remote branch of yours whose pull request merged at its last commit
# When a session starts in the repo
# Then the branch is gone from the remote
setup; branch feat; merge feat keep; on_main; git -C "$dir/repo" branch -q -D feat
run >/dev/null
check "T7 your merged remote branch goes" '! has_remote feat'


# Given a checkout on main, with nothing uncommitted, behind the remote
# When a session starts in the repo
# Then it matches the remote's main
setup; on_main; branch feat; merge feat; git -C "$dir/repo" switch -q main; git -C "$dir/repo" branch -q -D feat
run >/dev/null
check "T9 a clean main catches up" '[ "$(git -C "$dir/repo" rev-parse main)" = "$(git -C "$dir/origin.git" rev-parse main)" ]'


# Given a repo with a merged branch to tidy
# When a session starts in the repo
# Then the agent is told nothing about the tidy
# And you see one line, starting Tidied, naming what went and what stayed
setup; branch feat; merge feat; branch solo; git -C "$dir/repo" switch -q solo; echo s > "$dir/repo/s.txt"; git -C "$dir/repo" add s.txt; git -C "$dir/repo" commit -q -m s; on_main
worktree solo 2>/dev/null; git -C "$dir/repo" worktree add -q "$dir/wt-kept" -b kept origin/main 2>/dev/null; echo "kept MERGED $(git -C "$dir/repo" rev-parse kept)" >> "$dir/prs"; echo half > "$dir/wt-kept/notes.txt"
out=$(run)
msg=$(seen "$out")
check "T11 the agent hears nothing, you see one Tidied line" 'agent_silent "$out" && [ "$(wc -l <<<"$msg")" = 1 ] && grep -q "Tidied" <<<"$msg" && grep -qw feat <<<"$msg" && grep -qw kept <<<"$msg"'


# Given an agent in a session
# When it merges a pull request with gh or tea
# Then that pull request's branch is gone, locally and on the remote, except the worktree the session stands in
# And the agent is told nothing about the tidy
for forge in gh tea; do
  FORGE=$forge
  setup; branch feat; branch other; worktree other; on_main; busy "$dir/wt-other"; merge feat keep
  payload=$(jq -nc --arg c "$forge pr merge 1" --arg d "$dir/wt-other" '{hook_event_name: "PostToolUse", tool_name: "Bash", tool_input: {command: $c}, cwd: $d}')
  out=$(run "$dir/wt-other" "$payload")
  check "T13 a merge with $forge tidies at once" '! has_local feat && ! has_remote feat && [ -d "$dir/wt-other" ] && agent_silent "$out"'
done
FORGE=gh


# Given a Gitea repo with a local branch whose pull request merged
# When a session starts in the repo
# Then the branch is gone
FORGE=tea; setup; branch feat; merge feat keep; on_main
run >/dev/null
check "T14 Gitea works too" '! has_local feat'
FORGE=gh


# Given a fresh plugin install with the tidy setting untouched
# When a session starts in a repo with a merged branch
# Then the branch is gone
setup; branch feat; merge feat; on_main
run >/dev/null
check "T15 on by default" '! has_local feat && jq -e ".userConfig.auto_tidy.default == true" "$manifest" >/dev/null'


# Given a repo whose testing doc names its own worktree removal script
# When a merged worktree is tidied
# Then that script removes it
setup; branch feat; worktree feat; merge feat; on_main
mkdir -p "$dir/repo/docs/agents" "$dir/repo/scripts"
printf 'Drop worktree: scripts/drop.sh\n' > "$dir/repo/docs/agents/testing.md"
printf '#!/usr/bin/env bash\necho "$1" > "%s/dropped"\ngit worktree remove --force "$1"\n' "$dir" > "$dir/repo/scripts/drop.sh"; chmod +x "$dir/repo/scripts/drop.sh"
rm -f "$dir/dropped"; run >/dev/null
check "T17 the repo's own removal script" '[ "$(cat "$dir/dropped" 2>/dev/null)" = "$dir/wt-feat" ] && [ ! -d "$dir/wt-feat" ]'
rm -f "$dir/dropped"


# Given the plugin installed
# When you list its skills
# Then marie-kondo is not among them
check "T18 no marie-kondo skill" '! jq -r ".skills[]" "$manifest" | grep -q marie-kondo && [ -z "$(find "$skills" -type d -name marie-kondo)" ]'

exit $fail
