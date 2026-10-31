---
name: make-it-so
description: Finish a draft pull request and see it through CI — make it current and true, hold it to a measured QA checklist, mark it ready, then babysit CI until every required check is green. Use when the user says "make it so", "finish the PR", "mark it ready", "ship it", "babysit CI" or "make sure CI passes", and when `do` ends.
---

# Make it so

> _Make it so: current, true, ready, green._

A pull request opens early as a **draft**: a pull request that asks no one to review it yet (GitHub's Draft state, or a `WIP:` title prefix on Gitea, unless the repo's guide names another way). The draft collects the work. **Make it so** is the order that finishes it: current, checked by the user, true, ready, green. Merging stays with the user or the repo's own automation.

## Steps

1. **Finish the branch.** Commit everything. Run `git fetch origin`. When the branch is behind `main`, rebase it, with `history-monks` when what landed changes the form of what the branch touches. Run the checks the change reaches. Done when the tree is clean, the branch is current, and the checks pass.
2. **Run the QA checklist**, Q1 to Q6, below. Fix each failure in place and run the item again. This is not a review: `review` already ran, so a design concern goes to the user as a question. Done when Q1 to Q6 each pass, or Q5 has its reason in the body.
3. **Hand over what the build held.** When the effort has a draft file, open it with `red-pen` and commit what the user leaves. Then take the pull request's Check these list to the user, one line at a time. Fix each answer that differs from the guess, build each parked slice they unblock, and delete the list. Done when the draft file is gone and Check these is empty or holds only what waits on someone else.
4. **Make it true.** Run `ship-it` for the body and `loose-ends` for the tickets, then Q7 to Q10. Fix each failure in place and run the item again. Done when Q7 to Q10 each pass.
5. **Push once, then mark it ready.** Push a rebased branch with `git push --force-with-lease=<branch>:<old sha>`. Then mark it ready: `gh pr ready <n>` on GitHub, or on Gitea drop the `WIP:` prefix with `tea pr edit <n> -t "<title>" </dev/null`. Push first because a repo's bot may approve or merge the commit it sees when the pull request turns ready. When marking it ready starts no run (a Gitea workflow often ignores title edits), close and reopen the pull request. Done when the pull request shows as ready and its head is your last commit.
6. **Babysit CI.** Watch the run for the pushed commit: `gh pr checks <n> --watch --required` on GitHub, or poll `tea actions runs list` and `tea actions runs view <id>` on Gitea every minute, at most 60 times. Then:
   - **Green**: done.
   - **Red**: read the failing job's log (`tea actions runs logs <id>`, or the check's link), then read the latest run on the base branch (`gh run list --branch <base> --limit 1`, or `tea actions runs list`). Tell the user at once, in one line: the failing check, its cause, and whether the base branch fails the same way. Fix the cause on the branch, even when the base branch carries it, without asking first: a choice between fixes that each make the check pass honestly is yours, so name your pick in the one line and build it. Ask first only when every fix breaks the spec: an approved example, the ticket, or a decision on record. Fix it with `machine-spirit` when CI itself broke, and with `never-lupus` when the code did. A test that fails only some runs is red: rerun it locally until it fails, and fix it. Rerun the checks the fix reaches, push once, and watch again.
   - **Stuck or never reports**: run `machine-spirit`.

   A merge or approval only someone else can give is a gate: handle it as `warp`'s "Punch through" says, in a warp or not. Stop after three red rounds, or when the cause sits outside the repository, and report what you found. Done when Q11 passes.
7. **Report** in one or two lines: the pull request link, the run, its result, the checklist (`Q1-Q11 pass`, or each item that failed and why), and anything left for the user, such as the merge. Then run `cerebro` as a forecast. Done when the reply holds all of it.

## QA checklist

Each item passes or fails on a command's output or one read of named text. `<base>` is the pull request's base branch, after `git fetch origin`. A failing item is fixed, never only reported. An item you can't fix, such as a change too big to split this turn or a ticket that waits on someone else, goes in the body with its reason, and the report names it.

Measured by a command:

- **Q1 Current.** `git merge-base --is-ancestor origin/<base> HEAD` exits 0, and `git log --merges --oneline origin/<base>..HEAD` prints nothing.
- **Q2 Clean tree.** `git status --porcelain` prints nothing.
- **Q3 No leftovers.** The added lines of `git diff origin/<base>...HEAD` hold no conflict marker, debug print, commented-out code, focused or skipped test (`.only(`, `fit(`, `xit(`, `[Ignore]`, `t.Skip(`, `@skip`), or TODO without a ticket key. Every file `git diff --name-status origin/<base>...HEAD` adds is one the change needs.
- **Q4 Nothing leaks.** `loose-lips` over the diff, every commit message (`git log origin/<base>..HEAD`) and the body finds no hit.
- **Q5 Sized.** `git diff --shortstat origin/<base>...HEAD`, without lock and generated files, shows fewer than 400 lines inserted and deleted together, or the body says in one line why the change can't split.
- **Q6 Checks pass locally.** The checks the change reaches ran on the head commit and passed.
- **Q7 Linked.** Every ticket key in the branch name, the commits and the body appears in the body on a `Closes`, `Refs` or `Waits on` line, and `loose-ends` reports each one settled.

Measured by one read:

- **Q8 Title.** The title says what the change does, in the repo's title style, with no `WIP:` once ready.
- **Q9 What and why.** The body's first paragraph says what the change does and why. Every sentence is true of `git diff origin/<base>...HEAD`.
- **Q10 How tested.** The body names the tests or seams that prove the change, the mutation counts or why there are none, and anything left unchecked.

Measured after the push:

- **Q11 Green.** Every required check on the head commit is final and successful. No red check was rerun without a new commit.
