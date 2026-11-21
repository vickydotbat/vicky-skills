---
name: make-it-so
description: Finish a draft pull request and see it through CI. Use when the user types /make-it-so. Only the user starts it.
disable-model-invocation: true
---

# Make it so

> _Make it so: current, checked, true, ready, green._

A pull request opens early, and always, as a **draft**: a pull request that asks no one to review it yet (GitHub's Draft state, or a `WIP:` title prefix on Gitea, unless the repo's guide names another way). The draft collects the work, and stays a draft until the user asks for it to be ready; `draft-guard` refuses a ready mark in a session where this skill never started. **Make it so** is the order that finishes it: current, checked by the user, true, ready, green. Merging stays with the user or the repo's own automation.

Read the repo's testing standards first, where the `Testing standards:` line in `docs/agents/testing.md` names them (`TESTING_STANDARDS.md` at the root when the line is absent): they win over this skill's defaults.

## Steps

1. **Finish the branch.** Commit everything. Run `git fetch origin`. When the branch is behind its base branch, rebase it with `history-monks`, always, as `push-behind-guard` will refuse the push otherwise. Run the checks the change reaches. Done when the tree is clean, the branch is current, and the checks pass.
2. **Run the QA checklist**, Q0 to Q4, below. Q0 comes first. Fix each other failure in place and run the item again. A finding on an approved-spec test goes to the user as a question, through `examples`' "Changing an approved example". Q1 to Q4 are not a deathmatch: once Q0 passes, a new design concern goes to the user as a question. Done when Q0 to Q4 each pass, or Q4 has its reason in the body.
3. **Hand over what the build held.** When the effort has a draft file, open it with `red-pen` and commit what the user leaves. Then take the pull request's Check these list to the user, one line at a time (a live check goes through `over-to-you`, and make-it-so resumes in the fresh session its read-back asks for), except each line a statement of the user's in this effort already answers (a deferral such as "that can wait"): settle it with that statement, quoted, and ask nothing. Fix each answer that differs from the guess, build each parked slice they unblock, and delete the list. Done when the draft file is gone and Check these is empty or holds only lines marked `Waits on: <who else>`.
4. **Make it true.** Rewrite the body to `ship-it`'s template with `ship-it`, and settle every ticket the effort touched with [SETTLE.md](SETTLE.md), then Q5 to Q8 and Q10 to Q12. Fix each failure in place and run the item again. Done when Q5 to Q8 and Q10 to Q12 each pass.
5. **Push once, then mark it ready.** First prove the laws: run `bash ${CLAUDE_PLUGIN_ROOT}/skills/shipping/engrave/scripts/law-lint.sh prove <base>`, with the merge-base as `<base>`, and put the `Laws:` line it prints in the pull request body's Proof section. When it exits non-zero, a reached law's proof went red or the branch added a law with no proof: make-it-so does not mark it ready. Name the law and its proof, fix it, and run it again. A law that was unproven before the branch is listed as backlog, never a refusal. Under `Law proofs: off` it prints that, and nothing holds the ready mark. Mark it ready only when the repo's own rules allow it: some repos hold a queue in CI, and their docs say so. Push a rebased branch with `git push --force-with-lease=<branch>:<old sha>`. Then mark it ready: `gh pr ready <n>` on GitHub, or on Gitea drop the `WIP:` prefix with `tea pr edit <n> -t "<title>" </dev/null`. Push first because a repo's bot may approve or merge the commit it sees when the pull request turns ready. Wait until the push's own run shows in `gh run list --branch <branch> --limit 1` for your head commit before you mark it ready: a push event that lands after the ready event still sees a draft, and cancels the ready run. When marking it ready starts no run (a Gitea workflow often ignores title edits), close and reopen the pull request.
   - **The user's ready mark.** When the repo's guide hands the ready mark to the user, give them the exact command (`! gh pr ready <n>`, or `! tea pr edit <n> -t "<title>"`), and in the same turn start a watch on the pull request leaving draft: `watch.sh` under Monitor, its check `[ "$(gh pr view <n> --json isDraft -q .isDraft)" = false ]` on GitHub, or on Gitea one that passes once the title no longer starts `WIP:`. Their mark ends no flow: when the watch passes, or their next message shows the command, go on from the run check above, unasked. `ready-resume-hint` adds that reminder when their command shows.

   Done when the pull request shows as ready and its head is your last commit.
   Proven by: plugins/vicky-skills/evals/make-it-so/red-law-refuses-ready
6. **Babysit CI.** Watch the run for the pushed commit: `gh pr checks <n> --watch --required` on GitHub, or on Gitea wait on `tea actions runs view <id>` with `${CLAUDE_PLUGIN_ROOT}/scripts/watch.sh '<check>'`, run by the Monitor tool. A Gitea run is still going while its status is `queued`, `waiting`, `running` or `in_progress`; the watch's check ends only on a final one. A wait on the user, such as a merge, is a gate, as [GATES.md](../../GATES.md) says. When the watch exits 3, report each check still running and its run link, and leave the pull request as it is. Then:
   - **Green**: done.
   - **Stopped at the draft gate**: a run that ended at the repo's draft or `WIP:` gate, because it started before the pull request was ready, is the gate working, not red. Never report it as a failure: wait for the run the ready event starts, or close and reopen the pull request as step 5 says.
   - **Red**: read the failing job's log (`tea actions runs logs <id>`, or the check's link), then read the latest run on the base branch (`gh run list --branch <base> --limit 1`, or `tea actions runs list`). Tell the user at once, in one line: the failing check, its cause, and whether the base branch fails the same way. Fix the cause on the branch, even when the base branch carries it, without asking first: a choice between fixes that each make the check pass honestly is yours, so name your pick in the one line and build it. Ask first only when every fix breaks the spec: an approved example, the ticket, or a decision on record. Fix it with `machine-spirit` when CI itself broke, and with `never-lupus` when the code did. A test that fails only some runs is red: rerun it locally until it fails, and fix it. Rerun the checks the fix reaches, push once, and watch again.
   - **Killed by the runner**: the log shows the runner ended the step, not the code: a cancel or kill line, a lost runner, or exit -1 with no assertion, error or test output before it. A step that failed by itself is red, however odd, and so is one cancelled at the job's `timeout-minutes`: compare the cancel time with the job's start before you call it a kill. Run the job's steps locally on the head commit; when they pass, rerun only the failed jobs, once (on Gitea `tea api -X POST repos/<owner>/<repo>/actions/runs/<id>/rerun-failed-jobs </dev/null`, on GitHub `gh run rerun <id> --failed`), and name the kill line and the local pass in the body. A second red on the rerun is red.
   - **Stuck or never reports**: run `machine-spirit`.

   A merge or approval only someone else can give is a gate: handle it as `warp`'s "Punch through" says, in a warp or not. Stop after three red rounds, or when the cause sits outside the repository, and report what you found. Done when Q9 passes.
7. **Report** in one or two lines: the pull request link, the run, its result, the checklist (`Q0-Q12 pass`, or each item that failed and why), and anything left for the user, such as the merge. Once the pull request merges, run `cerebro` as a forecast: the `auto-tidy` hook clears the merged branch on its own. Done when the reply holds all of it.

**State at every stop.** Write the Status section at every stop, as `ship-it`'s "State at every stop" says.

## QA checklist

`<base>` is the pull request's base branch, after `git fetch origin`. A failing item is fixed, never only reported. An item you can't fix, such as a change too big to split this turn or a ticket that waits on someone else, goes in the body with its reason, and the report names it.

Measured by a command:

- **Q0 Deathmatched, and fresh.** Before it starts deathmatch, write the pull request body to a scratch file and run `bash ${CLAUDE_PLUGIN_ROOT}/skills/shipping/deathmatch/scripts/verdict.sh due <body file> <head sha>`. Run `deathmatch` only when that exits 0, with the pull request's merge-base as its fixed point, and fix each proven finding. It writes `Deathmatch verdict for <head sha>: <n> proven findings` in the body's Proof. When the script exits 1, the head commit already has its verdict: run nothing. A commit made after the verdict makes it due again. `do` never runs a review or a deathmatch.
- **Q1 No merge commits.** `git log --merges --oneline origin/<base>..HEAD` prints nothing. Step 1 has already made the branch current, its tree clean and its checks green on the head commit.
- **Q2 No leftovers.** The added lines of `git diff origin/<base>...HEAD` hold no conflict marker, debug print, commented-out code, focused or skipped test (`.only(`, `fit(`, `xit(`, `[Ignore]`, `t.Skip(`, `@skip`), or TODO without a ticket key. Every file `git diff --name-status origin/<base>...HEAD` adds is one the change needs.
- **Q3 Nothing leaks.** `loose-lips` over the diff, every commit message (`git log origin/<base>..HEAD`) and the body finds no hit.
- **Q4 Sized.** `git diff --shortstat origin/<base>...HEAD`, without lock and generated files, shows fewer than 400 lines inserted and deleted together, or the body says in one line why the change can't split.
- **Q5 Linked.** Every ticket key in the branch name, the commits and the body appears in the body on a `Closes`, `Refs` or `Waits on` line, and [SETTLE.md](SETTLE.md) has settled each one.

Measured by one read:

- **Q6 Title.** The title says what the change does, in the repo's title style, with no `WIP:` once ready.
- **Q7 What and why.** The body's first paragraph says what the change does and why. Every sentence is true of `git diff origin/<base>...HEAD`.
- **Q8 How tested.** The body names the approved examples and the tests that prove them, the mutation counts from `sentinels` (a hand-broken line counts as a pass and goes through it too), or `unrun, because <the log line or reason>`, and anything left unchecked. When the testing standards have a `Metrics:` line that isn't `none`, each rule the change sets with a written target has its metrics on its ticket, or a `Metrics owed: <rule>` line in the body. This item reads only that they are there, never what they found.
- **Q10 Current truth.** README, docs, agent files and project memory say nothing the diff makes untrue: grep each for the names, commands and rules the diff changes. Fix each hit in the branch, or name it in the body with its reason.
- **Q11 Nothing left behind.** Run the tracker's "List items created or changed since <time>" operation from `docs/agents/issue-tracker.md`, from the time of the branch's first commit (`git log --reverse --format=%cI origin/<base>..HEAD | head -1`). Every ticket it shows that this effort opened, or that names the effort's chart, sits in the body on a `Closes` line, or on a `Waits on` line whose reason is one SETTLE.md's "Waits" allows. Any other ticket is found work put off: build it on this branch, then run the item again. `Found work check: off` in `docs/agents/domain.md` skips this item.
- **Q12 Credited.** Each outside tool, library, font or asset the diff adopts has its credit, as STANDARDS.md's "Credit what you adopt" says, in the file the `Credits:` line in `docs/agents/domain.md` names. Take the licence from the source's own words and research nothing more. `Credits: off` skips this item.

Measured after the push:

- **Q9 Green.** Every required check on the head commit is final and successful. No red check was rerun without a new commit, except one rerun of a job the runner killed, as step 6 says.

Charter: C2, C4 ([CHARTER.md](../../CHARTER.md)).
