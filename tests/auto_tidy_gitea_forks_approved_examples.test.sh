#!/usr/bin/env bash
# shellcheck disable=SC2016 # check() evals its single-quoted condition later
# shellcheck disable=SC2034 # names set here are read inside check()'s eval
# shellcheck disable=SC2154 # fail is set by the fixture the fork fixture sources
# Approved examples G1 to G6 on the Auto-tidy gaps chart: your fork on a
# Gitea host gets the same tidy as your fork on GitHub.
set -u
# shellcheck source=lib/gitea-fork-fixture.sh
. "$(dirname "$0")/lib/gitea-fork-fixture.sh"

# Given a clone whose origin is on Gitea and whose second remote is your Gitea fork of it
# And a fork branch whose pull request to origin merged at that commit
# When a session starts in the clone
# Then the branch is gone from your fork
gsetup; fbranch fork.git feat; git -C "$dir/repo" fetch -q fork; land feat; on_main
run >/dev/null
check "G1 a merged branch on your Gitea fork goes" '! on fork.git feat'

# Given a branch on your Gitea fork with commits origin lacks and no open pull request
# When a session starts in the clone
# Then it stays, and the tidy line names it with the command that deletes it
gsetup; fbranch fork.git idea; git -C "$dir/repo" fetch -q fork; on_main
out=$(run)
check "G2 an unmerged branch on your Gitea fork stays and is named" 'on fork.git idea && seen "$out" | grep -q "idea" && seen "$out" | grep -q "git push fork --delete"'

# Given a remote on the Gitea host that someone else owns
# And it holds a branch named like one whose pull request merged
# When a session starts in the clone
# Then nothing on it changes
gsetup; git clone -q --bare "$dir/origin.git" "$dir/other.git"; git -C "$dir/repo" remote add theirs "$G/someone/proj.git"
fbranch other.git feat; git -C "$dir/repo" fetch -q theirs; echo "feat MERGED $(git -C "$dir/other.git" rev-parse feat)" >> "$dir/prs"; on_main
run >/dev/null
check "G3 a Gitea remote that is not your fork is never touched" 'on other.git feat'

# Given no tea login for the Gitea host, or a failing API call
# When a session starts in the clone
# Then the fork stays untouched and the session starts with no error
gsetup; fbranch fork.git feat; git -C "$dir/repo" fetch -q fork; land feat; rm "$dir/tea-logins"; on_main
out=$(run); code=$?
check "G4 no tea login leaves your Gitea fork alone" 'on fork.git feat && [ "$code" = 0 ] && agent_silent "$out"'
gsetup; fbranch fork.git feat; git -C "$dir/repo" fetch -q fork; land feat; touch "$dir/tea-down"; on_main
out=$(run); code=$?
check "G4 a failing Gitea API leaves your fork alone" 'on fork.git feat && [ "$code" = 0 ] && agent_silent "$out"'

# Given your Gitea fork with no clone on this machine, and a branch its parent holds
# When you run the fork sweep
# Then the branch is gone, and the fork's default branch matches its parent's
gsetup; fbranch fork.git feat; land feat; main_moves
out=$(gsweep)
check "G5 the sweep tidies your Gitea forks" '! on fork.git feat && [ "$(git -C "$dir/fork.git" rev-parse main)" = "$(git -C "$dir/origin.git" rev-parse main)" ] && grep -q "me/proj" <<<"$out"'

# Given workflow runs on your Gitea fork for a branch the tidy deletes
# When the tidy deletes the branch
# Then those runs are gone too, and a kept branch keeps its runs
gsetup; fbranch fork.git feat; fbranch fork.git shots; git -C "$dir/repo" fetch -q fork; land feat; printf 'me/proj feat 11\nme/proj shots 21\n' > "$dir/runs"; on_main
run >/dev/null
check "G6 a gone Gitea branch takes its workflow runs" '! on fork.git feat && ! grep -q " feat " "$dir/runs" && grep -q "shots 21" "$dir/runs"'

exit "$fail"
