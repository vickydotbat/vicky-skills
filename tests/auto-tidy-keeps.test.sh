#!/usr/bin/env bash
# HB-7 examples that held before the build: what auto-tidy must keep. They
# passed where they landed, so they are plain regression tests.
set -u
. "$(dirname "$0")/lib/auto-tidy-fixture.sh"

# Given a local branch with a commit on no remote
# When a session starts in the repo
# Then the branch is still there
setup; branch feat; merge feat; on_main
git -C "$dir/repo" switch -q feat; echo more > "$dir/repo/more.txt"; git -C "$dir/repo" add more.txt; git -C "$dir/repo" commit -q -m more; git -C "$dir/repo" switch -q main
run >/dev/null
check "T2 unpushed work stays" 'has_local feat'


# Given a worktree whose branch merged, with an uncommitted change
# When a session starts in the repo
# Then the worktree and its branch are still there
setup; branch feat; worktree feat; merge feat; on_main; echo half > "$dir/wt-feat/notes.txt"
run >/dev/null
check "T4 uncommitted changes stay" '[ -f "$dir/wt-feat/notes.txt" ] && has_local feat'


# Given a worktree whose branch merged, with another session working in it
# When a session starts in the repo
# Then the worktree is still there
setup; branch feat; worktree feat; merge feat; on_main; busy "$dir/wt-feat"
run >/dev/null
check "T5 a worktree in use stays" '[ -d "$dir/wt-feat" ]'


# Given a worktree whose branch is pushed but whose pull request is still open
# When a session starts in the repo
# Then the worktree is still there
setup; branch feat; worktree feat; on_main; echo "feat OPEN $(git -C "$dir/repo" rev-parse feat)" > "$dir/prs"
run >/dev/null
check "T6 pushed but unmerged stays" '[ -d "$dir/wt-feat" ] && has_local feat'


# Given a remote branch whose pull request merged, holding a commit by someone else
# When a session starts in the repo
# Then the branch is still on the remote
setup; git -C "$dir/repo" switch -q -c feat origin/main
echo x > "$dir/repo/x.txt"; git -C "$dir/repo" add x.txt
GIT_AUTHOR_EMAIL=someone@example.invalid git -C "$dir/repo" commit -q -m theirs
git -C "$dir/repo" push -q -u origin feat 2>/dev/null; merge feat keep; on_main; git -C "$dir/repo" branch -q -D feat
run >/dev/null
check "T8 someone else's remote branch stays" 'has_remote feat'


# Given a checkout on main with an uncommitted change, behind the remote
# When a session starts in the repo
# Then it stays where it was
setup; on_main; before=$(git -C "$dir/repo" rev-parse main); branch feat; merge feat; git -C "$dir/repo" switch -q main; git -C "$dir/repo" branch -q -D feat
echo half > "$dir/repo/notes.txt"; git -C "$dir/repo" add notes.txt
run >/dev/null
check "T10 a dirty main stays behind" '[ "$(git -C "$dir/repo" rev-parse main)" = "$before" ]'


# Given a repo with nothing to tidy
# When a session starts in the repo
# Then neither you nor the agent sees a tidy line
setup; on_main
out=$(run)
check "T12 nothing to tidy, nothing said" '[ -z "$out" ]'


# Given the tidy setting switched off
# When a session starts in a repo with a merged branch
# Then the branch is still there and nothing is said
setup; branch feat; merge feat; on_main
out=$(OPT=false run)
check "T16 switched off, nothing moves" 'has_local feat && [ -z "$out" ]'


exit $fail
