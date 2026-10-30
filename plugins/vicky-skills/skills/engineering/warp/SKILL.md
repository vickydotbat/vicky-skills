---
name: warp
description: Warp to one star in a single run, whatever it takes. It clears every anomaly, away team, probe and task on the star's course, then builds the star to green CI. Use when the user says "warp", "engage" or "get <ticket> done whatever it takes", or when `lay-course` engages warp.
---

# Warp

> _Engage. Every anomaly on the course is cleared, and the run ends at the star with CI green._

A **warp** reaches one target star in one run. It clears the star's **course**, which is the chain of open blockers from the frontier to the target, then builds the star. The words and ticket forms are in [STAR-CHART.md](../lay-course/STAR-CHART.md), and the tracker's commands in `docs/agents/issue-tracker.md`, "Star chart operations".

A warp is one effort: every star it builds goes on one branch and one pull request. It stops for the user only at an anomaly that needs a council or an interrogation, and at the target's examples.

## Steps

1. **Find the target.** Read the ticket the user named, whole, body and comments. Is it a star? Go on. Is it an anomaly or another kind? Ask which star it unblocks, and take that star as the target. Does no ticket exist yet? Ask the user to type `/lay-course <their goal>`, and stop: stars are placed there. Done when the target is a star you have read.
2. **Plot the course.** Walk the target's open blockers, then theirs, until every chain reaches a ticket with no open blocker. Order the course so each ticket comes after its blockers. A blocker on another chart counts. Done when every open blocker is on the course in order, or the course is empty.
3. **Light the course.** When the target is on a chart, redraw the chart with the course marked `course` (STAR-CHART.md, "Drawing the chart"). Post the course as a comment on the target: one line per ticket, in order. Done when the chart and the comment show the course.
4. **Clear the course**, one ticket at a time and in order. Claim each one before any other write.
   - **Away team**: dispatch `away-team` without asking. Go on with tickets that don't wait on it.
   - **Probe**: make it and show it. The user's reaction is its answer.
   - **Task**: do it. A task that needs another person, an account or a deploy stops the warp: report what waits and on whom.
   - **Anomaly**: stop for the user. Ask "Council or interrogation?", run the one they pick, and record it as `lay-course`, "Work the chart", steps 4 and 5 say.
   - **Star**: build it as step 5 does, minus `make-it-so`, on the warp's branch.

   Done when every ticket on the course is closed.
5. **Build the target.** When its Examples aren't approved yet, run `examples` and stop once for the user's approval. Then run `do`, `review` and `make-it-so`. Done when the pull request's required checks are green.
6. **Land.** Redraw the chart without the course, and run `loose-ends`. Done when every ticket the warp touched is settled.

When the user stops the warp partway, leave each cleared ticket closed and the rest open, and post where it stopped as a comment on the target.
