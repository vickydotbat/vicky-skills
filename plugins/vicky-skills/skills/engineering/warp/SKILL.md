---
name: warp
description: Warp to one star in a single run, whatever it takes. It clears every anomaly, away team, probe and task on the star's course, then builds the star to green CI. Use when the user says "warp", "engage" or "get <ticket> done whatever it takes", or when `lay-course` engages warp.
---

# Warp

> _Engage, and never drop out of warp: every obstacle is cleared, gone around or waited out, and the run ends at the star with CI green._

A **warp** reaches one target star in one run. It clears the star's **course**, which is the chain of open blockers from the frontier to the target, then builds the star. The words and ticket forms are in [STAR-CHART.md](../lay-course/STAR-CHART.md), and the tracker's commands in `docs/agents/issue-tracker.md`, "Star chart operations".

A warp is one effort: every star it builds goes on one branch and one pull request. **A warp never drops out.** It runs with the user away: every question, approval and refusal on the way is an **obstacle**, and "Punch through" below says what to do with each.

## Steps

1. **Find the target.** Read the ticket the user named, whole, body and comments. Is it a star? Go on. Is it an anomaly or another kind? Ask which star it unblocks, and take that star as the target. Does no ticket exist yet? Ask the user to type `/lay-course <their goal>`, and stop: stars are placed there. Claim it. Done when the target is a star you have read and claimed.
2. **Plot the course.** Walk the target's open blockers, then theirs, until every chain reaches a ticket with no open blocker. Order the course so each ticket comes after its blockers. A blocker on another chart counts. When an answer later adds or removes a blocker, plot the course again. Done when every open blocker is on the course in order, or the course is empty.
3. **Light the course.** Skip this step when the course is empty. When the target is on a chart, redraw the chart with the course marked `course` (STAR-CHART.md, "Drawing the chart"). Post the course as a comment on the target, written with `human-voice`: one line per ticket, in order. Done when the comment, and the chart if there is one, show the course.
4. **Clear the course**, one ticket at a time and in order. Claim each one before any other write.
   - **Away team**: dispatch `away-team` without asking, and close the ticket once its findings are posted. Go on with tickets that don't wait on it.
   - **Probe**: make it and show it. The user's reaction is its answer.
   - **Task**: do it. A task that needs another person, an account or a deploy is an obstacle.
   - **Anomaly**: ask the user "Council or interrogation?" once, with the findings it waited on, and keep working on what doesn't wait. When they answer, run the one they pick. When nothing else is left and no answer came, take the pick cheapest to undo from the findings, mark it `answered by warp, unreviewed`, and put it on the pull request's Check these list. Record it either way as [lay-course](../lay-course/SKILL.md), "Work the chart", steps 4 and 5 say.
   - **Star**: build it as step 5 does, minus `make-it-so`, on the warp's branch.

   Done when every ticket on the course is closed.
5. **Build the target.** When its Examples aren't approved yet, run `examples` and open the drafts with `red-pen`, then build against the drafts while the editor is open: an unchanged close approves them. Drafts still open at the end go on Check these, and their tests are marked `approved-spec` only once approved. Then run `do`, `review` and `make-it-so`. Done when the pull request's required checks are green.
6. **Land.** When the target is on a chart, redraw it without the course. Run `loose-ends`. Done when every ticket the warp touched is settled.

## Punch through

An obstacle is anything on the course that waits on someone else, or refuses: an answer, an approval, a merge, a review, a draft in the user's editor, a hook or a permission that says no. Take the first that works:

1. **Clear it with what you hold.** Use every authorization the user and the repo give you: a merge you may make, a bypass the user granted, a route the refusal itself names. Never work around what a refusal exists to stop.
2. **Go around it.** Keep working on everything that doesn't wait on it: other tickets on the course, the next slice, the other repositories. When the next step builds on the blocked one, build on top of it as a stack with `stacked-branches`: a warp is the user's standing ask for one.
3. **Sit at the gate**, only when nothing else is left and the gate should open soon. Ask for it once, then poll it once a minute, at most 60 times. Never end the turn at a gate, in a warp or in any other work: a reply with no tool call ends the run. After the 60th poll, report what the gate waits on and on whom.

A brief for an agent working a public repository holds it to `loose-lips`' attack-map test, never to a ban on every name: repository names, ticket keys and decision record numbers are navigation.

When the user stops the warp partway, leave each cleared ticket closed and the rest open, and post where it stopped as a comment on the target.
