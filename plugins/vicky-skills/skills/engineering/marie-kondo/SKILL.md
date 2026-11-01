---
name: marie-kondo
description: Tidy a repo's branches and worktrees — delete what merged, keep what sparks joy (unpushed work). Use when an effort lands, on any first visit to a repo in a session, or when the user asks to clean up branches or worktrees.
---

# Marie Kondo

> _A merged branch holds nothing. Thank it and let it go._

A branch **sparks joy** while it holds work that exists nowhere else. A branch whose pull request merged holds nothing: thank it and let it go. Squash merges leave commits that look unmerged, so `git branch --merged` proves nothing. The pull request's state decides.

## Steps

1. **Prune.** Run `git fetch --prune`. Done when the remote-tracking branches match the remote.
2. **Sort each local branch** with `git branch -vv` and the forge's pull request list (state `all`):
   - **Goes**: its pull request merged, or its upstream is `[gone]` after a merge.
   - **Stays**: it has commits on no remote, or its pull request is open.
   - **Ask**: no pull request and no upstream, with work you can't place.

   Judge what a branch still holds by comparing its head with the pull request's merged head (`gh pr view <n> --json state,headRefOid`, or `tea pr <n>`), never by the dates in a list. Standing on a "goes" branch, switch and move without asking: `git switch -c <name> origin/main`, then carry over only the commits after the merge. `merged-branch-guard` prints that list on a refused commit. Done when every branch is in one pile, and you stand on none from the "goes" pile.
3. **Remove the worktrees of the "goes" pile first**, with the repo's own removal script when its docs name one (it may clean data that `git worktree remove` can't). Done when `git worktree list` shows none of them.
4. **Delete the "goes" branches** with `git branch -d`. Use `-D` only when the merged pull request proves the work landed. Done when `git branch` shows none of them.
5. **Sweep the user's own remote branches.** List the remote's branches other than its default. One goes when every commit on it that the default branch lacks has the author email of `git config user.email`, and its work has landed: its pull request merged at the branch's current head, or, with no pull request, `git diff origin/<default>...origin/<branch>` shows only changes the default branch already holds. A branch with an open pull request, or any commit by someone else, stays. Delete each with `git push origin --delete <branch>`. Done when no remote branch of the user's holds only landed work.
6. **Fast-forward the default branch** in every checkout `git worktree list` shows and every repository nested under the repo's folder. In each one standing on its default branch with a clean tree and no commit the remote lacks, run `git fetch` then `git merge --ff-only`. Leave any other checkout as it is and name it in the report. Done when each such checkout's default branch matches its remote.
7. **Report** under the headline `✨ Tidied: <n> branches`, each deletion by name, local or remote, each branch kept with its reason, each checkout fast-forwarded or left behind, and the "ask" pile as one question. Done when all four are in your reply.

Every worktree lives in the repo's own `.claude/worktrees/` folder. A worktree `git worktree list` shows anywhere else is sorted like the rest, and a kept one moves there with `git worktree move <path> .claude/worktrees/<branch>`.

A remote branch is deleted only by step 5's rule, or when the user asks.
