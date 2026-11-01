---
name: gamma-shift
description: Work through the tickets waiting on the user. Each one whose wait is over gets built to a draft pull request, the rest are listed, and the user's open decisions come back as one round of questions. Use when the user says "gamma shift", "follow-ups" or "what's waiting on me", and when the session-start hook asks for a gamma-shift count or run.
---

# Gamma shift

> _You have the bridge, Number One. Build what's cleared, stop at a draft, and leave the rest on the captain's desk._

A **waiting ticket** is an open ticket with a `Waits on: <who or what>` line in its body, and it waits on the user when that line names them, in its tracker's not-started state where it has one. `loose-ends` parks a ticket this way, and the tracker's "Waiting work" section says how its tracker marks one when an effort can't finish it. A gamma shift checks each waiting ticket's wait and builds every one whose wait is over.

The run mode comes from its caller: `remind` from the session-start hook, `engage` from the hook or a typed run. The plugin setting is `${user_config.gamma_shift}`.

## Steps

1. **Find the tracker.** Read the "Waiting work" section of `docs/agents/issue-tracker.md`. When the file or the section is missing, say "gamma shift: this repo's tracker has no waiting list; `/first-contact` adds one" in a typed run, and stop silently in a hook run. Done when you have its "List waiting tickets" command, or "List tickets waiting on you" where it has no such line.
2. **List the waiting tickets** with that command. Read each one whole, body and comments. A ticket with no `Waits on:` line is assigned work, not waiting work: leave it off. In `remind` mode, count only those whose `Waits on:` line names the user, and open your first reply with `<n> follow-ups wait on you: run /gamma-shift`, or nothing when `<n>` is 0, and stop. Done when every listed ticket is read.
3. **Check each wait.** Read the thing the `Waits on:` line names, now:
   - A ticket or pull request: **cleared** when it is closed or merged.
   - A release, tag or deploy: **cleared** when the tag exists or the deployed version is the named one or newer.
   - Another person: **cleared** when the thread has their answer after the line was written.
   - The user's decision: **asks** the user. A decision answered in the thread since is **cleared**.
   - Anything still open: **waits**.

   Done when every ticket is cleared, waits or asks, with the evidence quoted.
4. **Build the cleared tickets**, one at a time, oldest first. For each, dispatch one background subagent with `isolation: "worktree"` and the brief below, then wait for its completion notification before the next. Any other wait goes through `${CLAUDE_PLUGIN_ROOT}/scripts/watch.sh '<check>'`, under the Monitor tool. You, the session's main thread, dispatch every subagent: a subagent never dispatches another. When the session-start hook said a `spark-joy` run is due, it goes last in the same queue: one background subagent with `isolation: "worktree"` that runs the `spark-joy` skill. It is the repo's health check, so it runs even when no ticket cleared. Done when every cleared ticket, and a due `spark-joy` run, has a draft pull request or a reason it stopped.
5. **Ask the decisions in one round.** For each ticket that asks: the question, two options at most, your pick and why, in one message. Write each answer into its ticket as a comment and drop the `Waits on:` line. A ticket whose answer clears it goes to step 4. Done when the user has answered or the round is sent.
6. **Report** in the form below. Done when the report is sent.

**State at every stop.** At every stop, write the pull request body's Status section, as `ship-it` says: a draft opened, a slice parked, a gate reached, the run ended. A ticket whose slice is parked: move its ticket back to the not-started state with a `Waits on:` line, as "Waiting work" in `docs/agents/issue-tracker.md` says.

## Subagent brief

```text
Build <ticket> to a draft pull request. You work alone: no question reaches the user, and you dispatch no agent.
1. Claim the ticket with "Claim a waiting ticket" in docs/agents/issue-tracker.md, before any other write. A claimed ticket drops off every other session's waiting list.
2. Read the agent file (CLAUDE.md or AGENTS.md) of the repo the ticket changes. When it says to commit straight to main, this is a trunk repo: git pull --rebase on main, build there, push to main, and open no pull request. Otherwise git fetch --prune, then git switch -c <ticket>-<slug> origin/main.
3. Run the `do` skill on the ticket, steps 1 to 5. The ticket is the request.
4. Unapproved examples: write them with `examples`, commit them, open the draft, and stop. Report "examples wait on the user's approval".
5. Run `loose-ends`. Stop at the draft: `make-it-so` is the user's call.
Report: the pull request link, its Check these list, and anything you skipped.
```

## Report

```text
Built (draft pull requests to read):
- <ticket>: <pull request link>, <n> Check these
- spark-joy: <pull request link>, <module folded in>, or Lean already
Still waiting:
- <ticket>: on <who or what>, <the evidence it is still open>
Questions:
Q1 <ticket>: <question> A) <option> B) <option>. Pick: <A or B>, <why>
```

A run with nothing to build, nothing waiting and no question reports one line: `gamma shift: nothing waits on you`.
