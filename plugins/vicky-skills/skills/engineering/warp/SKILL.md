---
name: warp
description: Warp through a star chart in a single run, whatever it takes: every star it can reach, or the stars the user names. It clears every anomaly, away team, probe and task on their course, then builds each star to green CI. Use when the user says "warp", "engage", "clear the chart" or "get <ticket> done whatever it takes", or when `lay-course` engages warp.
---

# Warp

> _Engage, and never drop out of warp: every obstacle is cleared, gone around or waited out, and the run ends at the last star with CI green._

A **warp** clears a whole star chart in one run, or the stars the user names. Each star it means to build is a **target**. It clears the targets' **course**, which is every open blocker from the frontier to each target, then builds the targets. A target is **in reach** when nothing on its course waits on another person, or on an account or deploy the user can't give this run. Out of reach, it stays open and the landing report names it. The words and ticket forms are in [STAR-CHART.md](../lay-course/STAR-CHART.md), and the tracker's commands in `docs/agents/issue-tracker.md`, "Star chart operations".

A warp is one effort: every star it builds goes on one branch and one pull request. **A warp never drops out.** Everything on the course that needs the user is taken with them in **pre-flight**, before engaging. A question that turns up mid-flight gets a seam or a stop at an asteroid belt ("Mid-flight questions" below). Every other approval and refusal on the way is an **obstacle**, and "Punch through" says what to do with each.

## Steps

1. **Find the targets.**
   - **Stars named**: each is a target.
   - **A chart named, or no star named**: every open star on the chart that is in reach is a target. With no chart named, take the chart this session works, and ask for one when there is none.
   - **An anomaly or another kind named**: the stars it blocks are the targets.
   - **Nothing to warp to**: ask the user to type `/lay-course <their goal>`, and stop: stars are placed there.

   Read each target whole, body and comments, and claim it. Done when every target is a star you have read and claimed.
2. **Plot the course.** First size up each target: read its body and the code it changes, and list what it needs that no ticket holds yet. File each as a star, or as an anomaly when it is an open question, on the target's chart, blocking the target. Then walk each target's open blockers, then theirs, until every chain reaches a ticket with no open blocker. The course is every target and every blocker found, each once, each after its blockers. A blocker on another chart counts. When an answer later adds or removes a blocker, plot the course again. Done when every need each target has is a ticket, and every open blocker and target is on the course in order.
3. **Light the course.** Redraw each chart the course crosses with the course marked `course` (STAR-CHART.md, "Drawing the chart"). Write the course as a table, one row per ticket in order: the ticket, its kind, and what it needs from the user, or "nothing". Post it, written with `human-voice`, as a comment on the chart, or on the one target when there is no chart. Done when the comment and every chart it crosses show the course.
4. **Pre-flight.** Open the course as an answer page (STAR-CHART.md, "Answer pages"): every chart it crosses, the course table, and the anomalies' questions with your picks. The user trims the course and answers there. Drop what they trim and plot the course again. Then list everything on the course that needs the user: each anomaly, each probe, each star's examples when they aren't approved, and each task that needs their account or a deploy. Dispatch the away teams the anomalies wait on first, and take the rest with the user while they run: run each anomaly's council or interrogation, show each probe, and approve the examples with `examples` and `red-pen`. Record each answer as [lay-course](../lay-course/SKILL.md), "Work the chart", steps 4 and 5 say. Done when nothing on the course waits on the user, or the user has said to leave one for mid-flight.
5. **Engage: clear the course**, one ticket at a time and in order. Claim each one before any other write.
   - **Away team**: dispatch `away-team` without asking, and close the ticket once its findings are posted. Go on with tickets that don't wait on it.
   - **Probe**: make it and show it. The user's reaction is its answer.
   - **Task**: do it. A task that needs another person, an account or a deploy is an obstacle.
   - **Anomaly** or **probe**: answered in pre-flight. One left for mid-flight is a mid-flight question.
   - **Star**, a target included: build it with `do` from its approved examples, on the warp's branch, and close it once its tests pass.

   Done when every ticket on the course is closed.
6. **Finish the build.** Run `review` over the whole branch, then `make-it-so`. A warp through several stars passes `make-it-so`'s size item with the body line "A warp through <n> stars, one pull request per effort." Done when the pull request's required checks are green.
7. **Land.** Redraw each chart the course crossed, without the course. Run `loose-ends`. Open the landing report with one sign-off line that drops out of warp, in the voice the session's output style sets ("🖖 Dropped out of warp. <n> stars are Done."). Then give the pull request, each target still open with what keeps it out of reach, and what is left. Done when every ticket the warp touched is settled and the landing report is sent.

## Mid-flight questions

A question only the user can answer that turns up after pre-flight never stops the build. Ask it once, then take one of two courses:

- **Carve a seam** when the target ships without the part the question holds. File that part as its own ticket on the chart, parked on the user with a `Waits on:` line, and narrow the target's body to what remains, the way `loose-ends` narrows a ticket. Build the rest.
- **Stop at an asteroid belt** when the question is one ([STAR-CHART.md](../lay-course/STAR-CHART.md), "Words"). Build around it, gather every such question, and at the end of the course drop out once, among the rocks, to take readings: one round of questions, each with your pick. Their answers re-engage the warp.

## Punch through

An obstacle is anything on the course that waits on someone else, or refuses: an answer, an approval, a merge, a review, a draft in the user's editor, a hook or a permission that says no. Take the first that works:

1. **Clear it with what you hold.** Use every authorization the user and the repo give you: a merge you may make, a bypass the user granted, a route the refusal itself names. Never work around what a refusal exists to stop.
2. **Go around it.** Keep working on everything that doesn't wait on it, but write no code for a star until its approved tests exist and fail (`draft-lock` and `red-first-guard` back this): other tickets on the course, the next slice, the other repositories. When the next step builds on the blocked one, build on top of it as a stack with `stacked-branches`: a warp is the user's standing ask for one.
3. **Sit at the gate**, only when nothing else is left and the gate should open soon. Ask for it once, in a message whose first line is `🚪 Waiting on you: <the one thing>`, then poll it every 30 seconds, at most 60 times (30 minutes), and send that line again every 15 minutes of waiting. The plugin's `gate_notify` hook turns the line into a desktop notification. Never end the turn at a gate, in a warp or in any other work: a reply with no tool call ends the run. After the 60th poll, send the `🚪` line once more, write the gate into the ticket or the pull request's Check these with a `Waits on:` line, and go on with any work that doesn't wait. With none left, end the turn on a report of what the gate waits on and on whom.

A brief for an agent working a public repository holds it to `loose-lips`' attack-map test, never to a ban on every name: repository names, ticket keys and decision record numbers are navigation.

When the user stops the warp partway, leave each cleared ticket closed and the rest open, and post where it stopped as a comment on the chart, or on each target still open when there is no chart.
