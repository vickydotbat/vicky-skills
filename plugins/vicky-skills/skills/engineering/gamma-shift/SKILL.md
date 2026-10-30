---
name: gamma-shift
description: Work through the tickets waiting on the user. Each one whose wait is over gets built to a draft pull request, the rest are listed, and the user's open decisions come back as one round of questions. Use when the user says "gamma shift", "follow-ups" or "what's waiting on me", and when the session-start hook asks for a gamma-shift count or run.
---

# Gamma shift

> _You have the bridge, Number One. Build what's cleared, stop at a draft, and leave the rest on the captain's desk._

A **waiting ticket** is an open ticket assigned to the user with a `Waits on: <who or what>` line in its body, in its tracker's not-started state where it has one. `loose-ends` parks a ticket this way, and the tracker's "Waiting work" section says how its tracker marks one when an effort can't finish it. A gamma shift checks each waiting ticket's wait and builds every one whose wait is over.

The run mode comes from its caller: `remind` from the session-start hook, `engage` from the hook or a typed run. The plugin setting is `${user_config.gamma_shift}`.

## Steps

1. **Find the tracker.** Read the "Waiting work" section of `docs/agents/issue-tracker.md`. When the file or the section is missing, say "gamma shift: this repo's tracker has no waiting list; `/first-contact` adds one" in a typed run, and stop silently in a hook run. Done when you have the list command.
2. **List the waiting tickets** with that command. Read each one whole, body and comments. A ticket with no `Waits on:` line is assigned work, not waiting work: leave it off. In `remind` mode, open your first reply with `<n> follow-ups wait on you: run /gamma-shift`, or nothing when `<n>` is 0, and stop. Done when every listed ticket is read.
3. **Check each wait.** Read the thing the `Waits on:` line names, now:
   - A ticket or pull request: **cleared** when it is closed or merged.
   - A release, tag or deploy: **cleared** when the tag exists or the deployed version is the named one or newer.
   - Another person: **cleared** when the thread has their answer after the line was written.
   - The user's decision: **asks** the user. A decision answered in the thread since is **cleared**.
   - Anything still open: **waits**.

   Done when every ticket is cleared, waits or asks, with the evidence quoted.
4. **Build the cleared tickets**, one at a time, oldest first. For each, dispatch one background subagent with `isolation: "worktree"` and the brief below, then wait for its completion notification before the next. You, the session's main thread, dispatch every subagent: a subagent never dispatches another. Done when every cleared ticket has a draft pull request or a reason it stopped.
5. **Ask the decisions in one round.** For each ticket that asks: the question, two options at most, your pick and why, in one message. Write each answer into its ticket as a comment and drop the `Waits on:` line. A ticket whose answer clears it goes to step 4. Done when the user has answered or the round is sent.
6. **Report** in the form below. Done when the report is sent.

## Subagent brief

```text
Build <ticket> to a draft pull request. You work alone: no question reaches the user, and you dispatch no agent.
1. Claim the ticket with "Claim a waiting ticket" in docs/agents/issue-tracker.md, before any other write. A claimed ticket drops off every other session's waiting list.
2. git fetch --prune, then git switch -c <ticket>-<slug> origin/main.
3. Run the `do` skill on the ticket, steps 1 to 6. The ticket is the request. Pick the seams yourself and list them under "Check these" in the pull request body.
4. Unapproved examples: write them with `examples`, commit them, open the draft, and stop. Report "examples wait on the user's approval".
5. Run `loose-ends`. Stop at the draft: `make-it-so` is the user's call.
Report: the pull request link, its Check these list, and anything you skipped.
```

## Report

```text
Built (draft pull requests to read):
- <ticket>: <pull request link>, <n> Check these
Still waiting:
- <ticket>: on <who or what>, <the evidence it is still open>
Questions:
Q1 <ticket>: <question> A) <option> B) <option>. Pick: <A or B>, <why>
```

A run with nothing to build, nothing waiting and no question reports one line: `gamma shift: nothing waits on you`.
