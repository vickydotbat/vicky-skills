---
name: gamma-shift
description: Work through the tickets waiting on the user. Use when the user says "gamma shift", "follow-ups" or "what's waiting on me", and when the session-start hook asks for a gamma-shift count or run.
---

# Gamma shift

> _You have the bridge, Number One. Build what's cleared, stop at a draft, and leave the rest on the captain's desk._

A **waiting ticket** is an open ticket with a `Waits on: <who or what>` line in its body, and it waits on the user when that line names them. The tracker's "Park a ticket" action marks one. `loose-ends` parks a ticket this way, and the tracker's "Waiting work" section says how its tracker marks one when an effort can't finish it. A gamma shift checks each waiting ticket's wait and builds one batch of the cleared ones. At `engage` it also runs `spark-joy` and the `ticket-drift` agent when the session-start hooks say one is due (`${user_config.deepen_every_days}` and `${user_config.drift_every_days}` days). Every build of one shift lands on one shared **gamma-shift branch**, `gamma-shift-<date>` with the shift's start date, and one draft pull request per repo: never the branch the user has checked out. The user's own work gets its own branch and pull request, and stacks on the gamma-shift pull request only when it needs a change from it. With nothing to build, make no branch and no pull request.

The run mode comes from its caller: `remind` from the session-start hook, `engage` from the hook or a typed run. The plugin setting is `${user_config.gamma_shift}`.

## Steps

1. **Find the tracker.** Read the "Waiting work" section of `docs/agents/issue-tracker.md`. When the file or the section is missing, say "gamma shift: this repo's tracker has no waiting list; `/first-contact` adds one" in a typed run, and stop silently in a hook run, unless the session-start hook said a `spark-joy` run is due: then run only that, as step 4 says. Done when you have its "List waiting tickets" command, or "List tickets waiting on you" where it has no such line.
2. **List the waiting tickets** with that command. Read each one whole, body and comments. A ticket with no `Waits on:` line is assigned work, not waiting work: leave it off. In `remind` mode, count only those whose `Waits on:` line names the user, and open your first reply with `<n> follow-ups wait on you: run /gamma-shift`, or nothing when `<n>` is 0, and stop. Read the repo's `.todo` lines outside the springboard block too: each is a standing order (`standing-orders`), and one whose wait is over is built like a cleared ticket. A line that names no star or ticket becomes one first: file it as a star with the line as its request, then rewrite the line to point at it. A line too big for one star is not charted here: it goes to step 5 as the question "chart it with `lay-course`?", since a chart is a design talk with the user, and the user types `/lay-course` to start it. Done when every listed ticket and `.todo` line is read.
3. **Check each wait.** Read the thing the `Waits on:` line names, now:
   - A ticket or pull request: **cleared** when it is closed or merged.
   - A release, tag or deploy: **cleared** when the tag exists or the deployed version is the named one or newer.
   - Another person: **cleared** when the thread has their answer after the line was written.
   - The user's decision: **asks** the user. A decision answered in the thread since is **cleared**.
   - Anything still open: **waits**.

   Done when every ticket is cleared, waits or asks, with the evidence quoted.
4. **Build one batch.** A batch is at most three cleared tickets, smallest first: the one whose examples and body promise the least change goes first. Dispatch one background subagent for the whole batch, with `isolation: "worktree"` and the brief below, naming the batch's tickets in order. It builds them in turn, each from the last one's push to the shared branch. One batch per session: when it finishes, no second batch starts by itself, and the next starts only when the user types "gamma shift". Any other wait is a gate, as [GATES.md](../../GATES.md) says, with `${CLAUDE_PLUGIN_ROOT}/scripts/watch.sh '<check>'` under the Monitor tool. You, the session's main thread, dispatch every subagent: a subagent never dispatches another. When the session-start hook said a `spark-joy` run is due, it goes last in the same queue: one background subagent with `isolation: "worktree"` and the spark-joy brief below. It is the repo's health check, so it runs even when no ticket cleared. When the hook said a drift check is due, start the `ticket-drift` agent as one background subagent at the start of the queue: it only comments, so it runs beside the builds. Done when every ticket in the batch and a due `spark-joy` run has a commit on the shared branch or a reason it stopped, and a due drift check has reported.
5. **Ask the decisions in one round.** For each ticket that asks: the question, two options at most, your pick and why, in one message. Write each answer into its ticket as a comment and drop the `Waits on:` line. A ticket whose answer clears it goes to step 4. Done when the user has answered or the round is sent.
6. **Report** in the form below. Done when the report is sent.

**State at every stop.** At every stop, write the pull request body's Status section, as `ship-it` says: a draft opened, a slice parked, a gate reached, the run ended. A ticket whose slice is parked: park its ticket with the tracker's "Park a ticket" action, with a `Waits on:` line, as "Waiting work" in `docs/agents/issue-tracker.md` says.

## Subagent brief

```text
Build <tickets>, in this order, one after another, onto one draft pull request. You work alone: no question reaches the user, and you dispatch no agent.
1. Claim the ticket with "Claim a waiting ticket" in docs/agents/issue-tracker.md, before any other write. A claimed ticket drops off every other session's waiting list.
2. Read the agent file (CLAUDE.md or AGENTS.md) of the repo the ticket changes. When it says to commit straight to main, this is a trunk repo: git pull --rebase on main, build there, push to main, and open no pull request. Otherwise git fetch --prune, then git switch --detach origin/gamma-shift-<date>, or origin/main when origin has no such branch yet. Push every commit with git push origin HEAD:gamma-shift-<date>. When that branch has no pull request, open one as a draft titled "Gamma shift <date>", with its body written by ship-it; otherwise add this ticket to its body. Never commit to any other branch.
3. No approved examples on the ticket: write drafts with `examples` steps 1 and 2 only, commit and push them to the shared branch, and stop. Report "examples wait on the user's approval". No page opens from a subagent.
4. Approved examples: start the `do` skill on the ticket with the Skill tool, steps 1 to 5: do is the build, and `do-first-guard` refuses code edits until it has started. The ticket is the request. Review (`do` step 6) waits for the user's merge pass.
5. Run `loose-ends`. Stop at the draft: `make-it-so` is the user's call.
Report: the pull request link, its Check these list, the mutation counts from `do`'s sentinels pass, and anything you skipped.
```

The spark-joy run gets the same brief with `spark-joy` in place of `do`: no ticket to claim, its own step 2 replaced by the shared-branch line above, and its draft pull request replaced by a commit and push to the shared branch.

## Report

```text
Built (one draft pull request per repo, gamma-shift-<date>):
<n> more waiting, say gamma shift for them
- <pull request link>: <tickets it builds>, <n> Check these
- spark-joy: <module folded in>, or Lean already
Drift comments:
- <ticket>: <the body line a comment or pull request contradicts>
Still waiting:
- <ticket>: on <who or what>, <the evidence it is still open>
Questions:
Q1 <ticket>: <question> A) <option> B) <option>. Pick: <A or B>, <why>
```

A run with nothing to build, nothing waiting and no question reports one line: `gamma shift: nothing waits on you`.

The `<n> more waiting, say gamma shift for them` line shows only when more than three cleared tickets wait, with `<n>` the count the batch left out.
