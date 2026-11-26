#!/usr/bin/env bash
# Approved examples for the Auto-tidy gaps chart, T5 to T13 and F1 to F8:
# auto-tidy clears your fork remote at session start, and the fork sweep, run
# by hand, clears your forks that have no clone.
set -u
. "$(dirname "$0")/lib/fork-fixture.sh"

# Given a clone whose origin is another person's repo and whose second remote is your fork
# And a branch whose pull request to origin merged
# When a session starts in the clone
# Then the branch is gone from the clone and from your fork
fsetup; fbranch fork.git feat; git -C "$dir/repo" fetch -q fork; git -C "$dir/repo" branch -q feat fork/feat; land feat; on_main
run >/dev/null
check "T5 a merged branch on your fork goes" '! on fork.git feat && ! has_local feat'

# Given a branch on your fork with commits origin's main lacks and no open pull request
# When a session starts in the clone
# Then the branch is still on your fork
# And the tidy line names it as unmerged, with the command that deletes it
fsetup; fbranch fork.git idea; on_main
out=$(run)
check "T6 unmerged branches on your fork are listed" 'on fork.git idea && seen "$out" | grep -q "unmerged" && seen "$out" | grep -q "idea" && seen "$out" | grep -q "git push fork --delete"'

# Given workflow runs on your fork for a branch the tidy deletes
# When the tidy deletes the branch
# Then those runs are gone too
fsetup; fbranch fork.git feat; land feat; printf 'me/proj feat 11\nme/proj feat 12\n' > "$dir/runs"; on_main
run >/dev/null
check "T7 a gone branch takes its workflow runs" '! on fork.git feat && ! grep -q " feat " "$dir/runs"'

# Given a fork of yours with no clone on this machine
# And branches that its parent repo already holds
# When you run the fork sweep
# Then those branches are gone
# And the fork's default branch matches its parent's
fsetup; fbranch fork.git feat; land feat; main_moves
runsweep >/dev/null
check "T8 forks with no clone get tidied" '! on fork.git feat && [ "$(git -C "$dir/fork.git" rev-parse main)" = "$(git -C "$dir/origin.git" rev-parse main)" ]'

# Given a branch on your fork that is the head of an open pull request on origin
# When a session starts in the clone
# Then the branch is still on your fork
fsetup; fbranch fork.git feat; land feat; sed -i 's/ MERGED / OPEN /' "$dir/prs"; on_main
run >/dev/null
check "T9 a fork branch with an open pull request stays" 'on fork.git feat'

# Given a branch on your fork with no merged pull request
# And commits that origin's main does not hold
# When a session starts in the clone
# Then the branch is still on your fork
fsetup; fbranch fork.git shots; on_main
run >/dev/null
check "T10 a fork branch no merge explains stays" 'on fork.git shots'

# Given workflow runs on your fork for a branch the tidy keeps
# When a session starts in the clone
# Then those runs are still there
fsetup; fbranch fork.git shots; printf 'me/proj shots 21\n' > "$dir/runs"; on_main
run >/dev/null
check "T11 runs of a branch that stays are kept" 'grep -q "shots 21" "$dir/runs"'

# Given a fork of yours with no clone on this machine
# And a branch with commits its parent repo lacks
# When you run the fork sweep
# Then the branch is still there
# And the sweep names it as unmerged
fsetup; fbranch fork.git idea
out=$(runsweep)
check "T12 the sweep keeps a branch the parent lacks" 'on fork.git idea && grep -q "unmerged" <<<"$out" && grep -q "idea" <<<"$out"'

# Given a fork whose default branch has commits its parent lacks
# When you run the fork sweep
# Then the default branch still has those commits
fsetup; rm -rf "$dir/w"; git clone -q "$dir/fork.git" "$dir/w" 2>/dev/null; echo mine > "$dir/w/mine.txt"; git -C "$dir/w" add mine.txt; git -C "$dir/w" commit -q -m mine; git -C "$dir/w" push -q origin main 2>/dev/null; mine=$(git -C "$dir/w" rev-parse HEAD); rm -rf "$dir/w"
out=$(runsweep)
check "T13 the sweep keeps your own commits on the default branch" 'git -C "$dir/fork.git" merge-base --is-ancestor "$mine" main && grep -q "me/proj" <<<"$out"'

# Given a clone whose second remote is a repo that is not yours, or whose parent is not origin
# And it holds a branch named like one whose pull request merged
# When a session starts in the clone
# Then that remote keeps every branch
fsetup; git clone -q --bare "$dir/origin.git" "$dir/other.git"; git -C "$dir/repo" remote add theirs https://github.com/someone/proj.git
fbranch other.git feat; git -C "$dir/repo" fetch -q theirs; echo "feat MERGED $(git -C "$dir/other.git" rev-parse feat)" >> "$dir/prs"; on_main
run >/dev/null
check "F1 a remote that is not your fork is never touched" 'on other.git feat'

# Given a merged pull request whose head branch on your fork now points at a newer commit
# When a session starts in the clone
# Then the branch is still on your fork
fsetup; fbranch fork.git feat; land feat
rm -rf "$dir/w"; git clone -q "$dir/fork.git" "$dir/w" 2>/dev/null; git -C "$dir/w" switch -q feat; echo more >> "$dir/w/feat.txt"; git -C "$dir/w" commit -q -am more; git -C "$dir/w" push -q origin feat 2>/dev/null; rm -rf "$dir/w"; on_main
run >/dev/null
check "F2 a branch that moved after its merge stays" 'on fork.git feat'

# Given a fork with 55 unmerged branches and no open pull requests
# When a session starts in the clone
# Then the tidy line is one line
# And it gives their count and the command that deletes them, not 55 names
fsetup; rm -rf "$dir/w"; git clone -q "$dir/fork.git" "$dir/w" 2>/dev/null
for i in $(seq 55); do git -C "$dir/w" switch -q -c "idea$i" origin/main; echo "$i" > "$dir/w/i.txt"; git -C "$dir/w" add i.txt; git -C "$dir/w" commit -q -m "i$i"; done
git -C "$dir/w" push -q origin --all 2>/dev/null; rm -rf "$dir/w"; on_main
out=$(run); msg=$(seen "$out")
check "F3 many unmerged branches keep the line to one" '[ "$(wc -l <<<"$msg")" = 1 ] && grep -q "55" <<<"$msg" && grep -q "git push fork --delete" <<<"$msg" && [ "$(grep -o "idea[0-9]*" <<<"$msg" | wc -l)" -lt 55 ] && on fork.git idea55'

# Given a branch on your fork
# And the pull request lookup on origin fails
# When a session starts in the clone
# Then the branch is still on your fork
fsetup; fbranch fork.git feat; land feat; touch "$dir/prs-fail"; on_main
run >/dev/null
check "F4 a failed lookup deletes nothing" 'on fork.git feat'

# Given a fork of yours with no clone, and a branch its parent already holds
# And an open pull request whose head is that branch
# When you run the fork sweep
# Then the branch is still there
fsetup; fbranch fork.git feat; land feat; sed -i 's/ MERGED / OPEN /' "$dir/prs"
out=$(runsweep)
check "F5 the sweep keeps an open pull request's branch" 'on fork.git feat && grep -q "me/proj" <<<"$out"'

# Given a fork of yours with no clone
# And a branch whose work its parent holds through a squash merge
# When you run the fork sweep
# Then the branch is gone
fsetup; fbranch fork.git feat; land feat; main_moves
runsweep >/dev/null
check "F6 a squash-merged branch goes in the sweep" '! on fork.git feat'

# Given a fork of yours with no clone, and its parent cannot be read
# When you run the fork sweep
# Then every branch is still there
# And the sweep says it could not compare them
fsetup; fbranch fork.git feat; land feat; rm -rf "$dir/origin.git"
out=$(runsweep)
check "F7 the sweep keeps everything when the parent cannot be read" 'on fork.git feat && grep -q "could not compare" <<<"$out"'

# Given a fork whose default branch has its own commits and is behind its parent
# When you run the fork sweep
# Then the default branch tip is unchanged
fsetup; rm -rf "$dir/w"; git clone -q "$dir/fork.git" "$dir/w" 2>/dev/null; echo mine > "$dir/w/mine.txt"; git -C "$dir/w" add mine.txt; git -C "$dir/w" commit -q -m mine; git -C "$dir/w" push -q origin main 2>/dev/null; rm -rf "$dir/w"; main_moves
tip=$(git -C "$dir/fork.git" rev-parse main)
out=$(runsweep)
check "F8 a diverged default branch is not reset" '[ "$(git -C "$dir/fork.git" rev-parse main)" = "$tip" ] && grep -q "me/proj" <<<"$out"'

exit $fail
