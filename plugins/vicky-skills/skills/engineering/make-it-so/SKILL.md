---
name: make-it-so
description: Finish a draft pull request and see it through CI — make it current and true, give it one light QA pass, mark it ready, then babysit CI until every required check is green. Use when the user says "make it so", "finish the PR", "mark it ready", "ship it", "babysit CI" or "make sure CI passes", and when `do` ends.
---

# Make it so

> _Make it so: current, true, ready, green._

A pull request opens early as a **draft**: a pull request that asks no one to review it yet (GitHub's Draft state, or a `WIP:` title prefix on Gitea, unless the repo's guide names another way). The draft collects the work. **Make it so** is the order that finishes it: current, checked by the user, true, ready, green. Merging stays with the user or the repo's own automation.

## Steps

1. **Finish the branch.** Commit everything. Run `git fetch origin`. When the branch is behind `main`, rebase it, with `history-monks` when what landed changes the form of what the branch touches. Run the checks the change reaches. Done when the tree is clean, the branch is current, and the checks pass.
2. **Run one light QA pass.** Read `git diff <base>...HEAD` once, looking only for leftovers: debug output, commented-out code, stray or generated files, a TODO with no ticket, a skipped or focused test, and anything `loose-lips` would refuse. Fix each in place. This is not a review: `review` already ran, so a design concern goes to the user as a question. Done when one read finds no leftover.
3. **Hand over what the build held.** When the effort has a draft file, open it with `red-pen` and commit what the user leaves. Then take the pull request's Check these list to the user, one line at a time. Fix each answer that differs from the guess, build each parked slice they unblock, and delete the list. Done when the draft file is gone and Check these is empty or holds only what waits on someone else.
4. **Make it true.** Run `ship-it` for the body and `loose-ends` for the tickets. Done when every sentence of the body matches the diff and every touched ticket is settled.
5. **Push once, then mark it ready.** Push a rebased branch with `git push --force-with-lease=<branch>:<old sha>`. Then mark it ready: `gh pr ready <n>` on GitHub, or on Gitea drop the `WIP:` prefix with `tea pr edit <n> -t "<title>" </dev/null`. Push first because a repo's bot may approve or merge the commit it sees when the pull request turns ready. When marking it ready starts no run (a Gitea workflow often ignores title edits), close and reopen the pull request. Done when the pull request shows as ready and its head is your last commit.
6. **Babysit CI.** Watch the run for the pushed commit: `gh pr checks <n> --watch --required` on GitHub, or poll `tea actions runs list` and `tea actions runs view <id>` on Gitea every minute, at most 60 times. Then:
   - **Green**: done.
   - **Red**: read the failing job's log (`tea actions runs logs <id>`, or the check's link). Fix the cause on the branch: with `machine-spirit` when CI itself broke, and with `never-lupus` when the code did. Rerun the checks the fix reaches, push once, and watch again.
   - **Stuck or never reports**: run `machine-spirit`.

   Stop after three red rounds, or when the cause sits outside the branch, and report what you found. Done when every required check is green on the head commit.
7. **Report** in one or two lines: the pull request link, the run, its result, and anything left for the user, such as the merge. Done when the reply holds all of it.
