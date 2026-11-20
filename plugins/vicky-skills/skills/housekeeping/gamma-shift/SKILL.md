---
name: gamma-shift
description: Work through the tickets waiting on the user. Use when the user types /gamma-shift.
disable-model-invocation: true
---

# Gamma shift

> _You have the bridge, Number One. Build what's cleared, stop at a draft._

A **waiting ticket** is an open ticket with a `Waits on: <who or what>` line in its body, and it waits on the user when that line names them. The tracker's "Park a ticket" action marks one. `make-it-so`'s SETTLE.md parks a ticket this way, and the tracker's "Waiting work" section says how its tracker marks one when an effort can't finish it. A gamma shift checks each waiting ticket's wait and builds one batch of the cleared ones. Every build of one shift lands on one shared **gamma-shift branch**, `gamma-shift-<date>` with the shift's start date, and one draft pull request per repo: never the branch the user has checked out. The user's own work gets its own branch and pull request, and stacks on the gamma-shift pull request only when it needs a change from it. With nothing to build, make no branch and no pull request.

**Outside report.** When you are handed a bug report or review that someone else wrote, first run `bash ${CLAUDE_PLUGIN_ROOT}/skills/shipping/deathmatch/scripts/mark-outside.sh <session id> <what>`, then run `deathmatch` to check the report's claims. In that run, fix nothing, push nothing and post nothing.

## Steps

1. **Find the tracker.** Read the "Waiting work" section of `docs/agents/issue-tracker.md`. When the file or the section is missing, say "gamma shift: this repo's tracker has no waiting list; `/first-contact` adds one" and stop. Done when you have its "List waiting tickets" command, or "List tickets waiting on you" where it has no such line.
   Proven by: plugins/vicky-skills/evals/gamma-shift/no-tracker
2. **List the waiting tickets** with that command. Read each one whole, body and comments. A star's chart binds it: read the chart whole too, body and comments, and treat its Prime directive and Sensor log as premises. A ticket with no `Waits on:` line is assigned work, not waiting work: leave it off. Read the repo's `.todo` lines outside the springboard block too: each is a standing order (`standing-orders`), and one whose wait is over is built like a cleared ticket. A line that names no star or ticket becomes one first: file it as a star with the line as its request, then rewrite the line to point at it. A line too big for one star is not charted here: it goes to step 5 as the question "chart it with `lay-course`?", since a chart is a design talk with the user, and the user types `/lay-course` to start it. Done when every listed ticket and `.todo` line is read.
   Proven by: plugins/vicky-skills/evals/gamma-shift/asks-the-decision
3. **Check each wait.** Read the thing the `Waits on:` line names, now:
   - A ticket or pull request: **cleared** when it is closed or merged.
   - A release, tag or deploy: **cleared** when the tag exists or the deployed version is the named one or newer.
   - Another person: **cleared** when the thread has their answer after the line was written.
   - The user's decision: **asks** the user. A decision answered in the thread since is **cleared**.
   - Anything still open: **waits**.

   Done when every ticket is cleared, waits or asks, with the evidence quoted.
4. **Build one batch.** A batch is at most three cleared tickets, smallest first: the one whose examples and body promise the least change goes first. Dispatch one background subagent for the whole batch, with `isolation: "worktree"` and the brief below, naming the batch's tickets in order. It builds them in turn, each from the last one's push to the shared branch. One batch per session: when it finishes, no second batch starts by itself, and the next starts only when the user types `/gamma-shift`. Any other wait is a gate, as [GATES.md](../../GATES.md) says, with `${CLAUDE_PLUGIN_ROOT}/scripts/watch.sh '<check>'` under the Monitor tool. You, the session's main thread, dispatch every subagent: a subagent never dispatches another. Done when every ticket in the batch has a commit on the shared branch or a reason it stopped.
   Proven by: plugins/vicky-skills/evals/gamma-shift/asks-the-decision
5. **Ask the decisions in one round.** For each ticket that asks: the question, two options at most, your pick and why, in one message. Write each answer into its ticket as a comment and drop the `Waits on:` line. A ticket whose answer clears it goes to step 4. Done when the user has answered or the round is sent.
6. **Report** in the form below. Done when the report is sent.

**State at every stop.** Write the Status section at every stop, as `ship-it`'s "State at every stop" says. A ticket whose slice is parked: park its ticket with the tracker's "Park a ticket" action, with a `Waits on:` line, as "Waiting work" in `docs/agents/issue-tracker.md` says.

## Subagent brief

```text
Build <tickets>, in this order, one after another, onto one draft pull request. You work alone: no question reaches the user, and you dispatch no agent.
1. Claim the ticket with "Claim a waiting ticket" in docs/agents/issue-tracker.md, before any other write. A claimed ticket drops off every other session's waiting list.
2. Read the agent file (CLAUDE.md or AGENTS.md) of the repo the ticket changes. When it says to commit straight to main, this is a trunk repo: git pull --rebase on main, build there, push to main, and open no pull request. Otherwise git fetch --prune, then git switch --detach origin/gamma-shift-<date>, or origin/main when origin has no such branch yet. Push every commit with git push origin HEAD:gamma-shift-<date>. When that branch has no pull request, open one as a draft titled "Gamma shift <date>", with its body written by ship-it; otherwise add this ticket to its body with ship-it, keeping its sections. Never commit to any other branch.
3. No approved examples on the ticket: write drafts with `examples` steps 1 and 2 only, commit and push them to the shared branch, and stop. Report "examples wait on the user's approval". No page opens from a subagent.
4. Approved examples: start the `do` skill on the ticket with the Skill tool, steps 1 to 5: do is the build, and its pull request body carries an `Examples:` line. The ticket is the request. Deathmatch runs later, inside `make-it-so`.
5. Settle the tickets with `make-it-so`'s [SETTLE.md](../../shipping/make-it-so/SETTLE.md). Stop at the draft: `make-it-so` is the user's call.
Report: the pull request link, its Check these list, the mutation counts from `do`'s sentinels pass, and anything you skipped.
```

## Report

```text
Built (one draft pull request per repo, gamma-shift-<date>):
<n> more waiting, type /gamma-shift for them
- <pull request link>: <tickets it builds>, <n> Check these
Still waiting:
- <ticket>: on <who or what>, <the evidence it is still open>
Questions:
Q1 <ticket>: <question> A) <option> B) <option>. Pick: <A or B>, <why>
```

A run with nothing to build, nothing waiting and no question reports one line: `gamma shift: nothing waits on you`.

The `<n> more waiting, type /gamma-shift for them` line shows only when more than three cleared tickets wait, with `<n>` the count the batch left out.

Charter: C5, C6 ([CHARTER.md](../../CHARTER.md)).
