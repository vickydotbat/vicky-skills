---
name: warp
description: Warp to one star in a single run, whatever it takes. It clears every anomaly, away team, probe and task on the star's course, then builds the star to green CI. Use when the user says "warp", "engage" or "get <ticket> done whatever it takes", or when `lay-course` engages warp.
---

# Warp

> _Engage, and never drop out of warp: every obstacle is cleared, gone around or waited out, and the run ends at the star with CI green._

A **warp** reaches one target star in one run. It clears the star's **course**, which is the chain of open blockers from the frontier to the target, then builds the star. The words and ticket forms are in [STAR-CHART.md](../lay-course/STAR-CHART.md), and the tracker's commands in `docs/agents/issue-tracker.md`, "Star chart operations".

A warp is one effort: every star it builds goes on one branch and one pull request. **A warp never drops out.** Everything on the course that needs the user is taken with them in **pre-flight**, before engaging. A question that turns up mid-flight gets a seam or a stop at an asteroid belt ("Mid-flight questions" below). Every other approval and refusal on the way is an **obstacle**, and "Punch through" says what to do with each.

## Steps

1. **Find the target.** Read the ticket the user named, whole, body and comments. Is it a star? Go on. Is it an anomaly or another kind? Ask which star it unblocks, and take that star as the target. Does no ticket exist yet? Ask the user to type `/lay-course <their goal>`, and stop: stars are placed there. Claim it. Done when the target is a star you have read and claimed.
2. **Plot the course.** Walk the target's open blockers, then theirs, until every chain reaches a ticket with no open blocker. Order the course so each ticket comes after its blockers. A blocker on another chart counts. When an answer later adds or removes a blocker, plot the course again. Done when every open blocker is on the course in order, or the course is empty.
3. **Light the course.** Skip this step when the course is empty. When the target is on a chart, redraw the chart with the course marked `course` (STAR-CHART.md, "Drawing the chart"). Post the course as a comment on the target, written with `human-voice`: one line per ticket, in order. Done when the comment, and the chart if there is one, show the course.
4. **Pre-flight.** List everything on the course that needs the user: each anomaly, each probe, the target's examples when they aren't approved, and each task that needs their account or a deploy. Dispatch the away teams the anomalies wait on first, and take the rest with the user while they run: run each anomaly's council or interrogation, show each probe, and approve the examples with `examples` and `red-pen`. Record each answer as [lay-course](../lay-course/SKILL.md), "Work the chart", steps 4 and 5 say. Done when nothing on the course waits on the user, or the user has said to leave one for mid-flight.
5. **Engage: clear the course**, one ticket at a time and in order. Claim each one before any other write.
   - **Away team**: dispatch `away-team` without asking, and close the ticket once its findings are posted. Go on with tickets that don't wait on it.
   - **Probe**: make it and show it. The user's reaction is its answer.
   - **Task**: do it. A task that needs another person, an account or a deploy is an obstacle.
   - **Anomaly** or **probe**: answered in pre-flight. One left for mid-flight is a mid-flight question.
   - **Star**: build it as step 6 does, minus `make-it-so`, on the warp's branch.

   Done when every ticket on the course is closed.
6. **Build the target** from the examples approved in pre-flight. Run `do`, `review` and `make-it-so`. Done when the pull request's required checks are green.
7. **Land.** When the target is on a chart, redraw it without the course. Run `loose-ends`. Done when every ticket the warp touched is settled.

## Mid-flight questions

A question only the user can answer that turns up after pre-flight never stops the build. Ask it once, then take one of two courses:

- **Carve a seam** when the target ships without the part the question holds. File that part as its own ticket on the chart, parked on the user with a `Waits on:` line, and narrow the target's body to what remains, the way `loose-ends` narrows a ticket. Build the rest.
- **Stop at an asteroid belt** when the target can't ship without it. Build around it, gather every such question, and at the end of the course drop out once, among the rocks, to take readings: one round of questions, each with your pick. Their answers re-engage the warp.

## Punch through

An obstacle is anything on the course that waits on someone else, or refuses: an answer, an approval, a merge, a review, a draft in the user's editor, a hook or a permission that says no. Take the first that works:

1. **Clear it with what you hold.** Use every authorization the user and the repo give you: a merge you may make, a bypass the user granted, a route the refusal itself names. Never work around what a refusal exists to stop.
2. **Go around it.** Keep working on everything that doesn't wait on it: other tickets on the course, the next slice, the other repositories. When the next step builds on the blocked one, build on top of it as a stack with `stacked-branches`: a warp is the user's standing ask for one.
3. **Sit at the gate**, only when nothing else is left and the gate should open soon. Ask for it once, then poll it once a minute, at most 60 times. Never end the turn at a gate, in a warp or in any other work: a reply with no tool call ends the run. After the 60th poll, report what the gate waits on and on whom.

A brief for an agent working a public repository holds it to `loose-lips`' attack-map test, never to a ban on every name: repository names, ticket keys and decision record numbers are navigation.

When the user stops the warp partway, leave each cleared ticket closed and the rest open, and post where it stopped as a comment on the target.
