---
name: warp
description: Warp through a star chart in a single run, whatever it takes: every star it can reach, or the stars the user names. Use when the user says "warp", "engage", "clear the chart" or "get <ticket> done whatever it takes", or when `lay-course` engages warp.
---

# Warp

> _Engage, and never drop out of warp: every obstacle is cleared, gone around or waited out, and the run ends at the last star with CI green._

A **warp** clears a whole star chart in one run, or the stars the user names: it achieves `do` on every star of the course, whatever it takes. Each star it means to build is a **target**. It clears the targets' **course**, which is every open blocker from the frontier to each target, then builds the targets. A target is **in reach** when nothing on its course waits on another person, or on an account or deploy the user can't give this run. Out of reach, it stays open and the landing report names it. The words and ticket forms are in [STAR-CHART.md](../lay-course/STAR-CHART.md), and the tracker's commands in `docs/agents/issue-tracker.md`, "Star chart operations".

A warp is one effort: every star it builds goes on one branch and one pull request. **A warp never drops out.** Everything on the course that needs the user is taken with them in **pre-flight**, before engaging. A question that turns up mid-flight gets a seam or a stop at an asteroid belt ("Mid-flight questions" below). Every other approval and refusal on the way is an **obstacle**, and "Punch through" says what to do with each.

**Zero friction.** Pre-flight is the one stop, and it stays small. After it, the user may be gone: anything you ask carries your pick, and an ask left unanswered gets that pick. A reply with no tool call ends the run, so a message that names the next step carries that step's tool call with it. Answering a side ask, or reading a background agent's or away team's report, never ends the turn: the same response carries the next course step's tool call (`idle-stop-guard` sends back a turn that ends without one).

## Steps

1. **Find the targets.**
   - **Stars named**: each is a target.
   - **A chart named, or no star named**: every open star on the chart that is in reach is a target. With no chart named, take the chart this session works, and ask for one when there is none.
   - **An anomaly or another kind named**: the stars it blocks are the targets.
   - **Nothing to warp to**: ask the user to type `/lay-course <their goal>`, and stop: stars are placed there.

   When the chart is too big for one run and you offer the user a choice of scopes, read every ticket in each scope first, and name in each option what it needs from the user (sketches, wording reads, art, decisions). An option that says "nothing from you" is true only of tickets you have read.

   Read each chart the targets sit on whole, body and comments: its Prime directive and Sensor log bind every star on it, so each is a premise of every build step. Then read each target whole, body and comments, and claim it. Done when every chart and every target is read, each Prime directive line is quoted in your notes, and every target is claimed.
2. **Plot the course.** First size up each target: read its body and the code it changes, and list what it needs that no ticket holds yet. File each as a star through [STAR-CHART.md](../lay-course/STAR-CHART.md)'s "Filing a star", or as an anomaly when it is an open question, on the target's chart, blocking the target. Then walk each target's open blockers, then theirs, until every chain reaches a ticket with no open blocker. The course is every target and every blocker found, each once, each after its blockers. A blocker on another chart counts. When an answer later adds or removes a blocker, plot the course again. Done when every need each target has is a ticket, and every open blocker and target is on the course in order.
3. **Light the course.** Redraw each chart the course crosses with the course marked `course` (STAR-CHART.md, "Drawing the chart"). Write the course as a table, one row per ticket in order: the ticket, its kind, a star's premises as `<n> known, <n> unknown`, and what it needs from the user, or "nothing". Post it, written with `human-voice`, as a comment on the chart, or on the one target when there is no chart. Done when the comment and every chart it crosses show the course.
4. **Pre-flight.** Open the course as an answer page (STAR-CHART.md, "Answer pages"): every chart it crosses, the course table, and the anomalies' questions with your picks. The user trims the course and answers there. Drop what they trim and plot the course again. Ask only what the course can't fly without, in one round: a choice with a pick that is cheap to undo is yours to take, named on the page. Then list everything on the course that needs the user: each anomaly, each `Confirm:` line under the chart's Knowns, each probe, each star's examples when they aren't approved (a star that changes a window's layout gets its `drawing-board` sketch approved first, since the sketch sets the examples' sizes), and each task that needs their account or a deploy. Dispatch the away teams the anomalies wait on first, and take the rest with the user while they run: run each anomaly's council or interrogation, show each probe, and approve the examples with `examples` and `red-pen`. Record each answer as [lay-course](../lay-course/SKILL.md), "Work the chart", steps 4 and 5 say. Once the examples are approved, write every approved test on the course in one step, run them red, and commit them, before engaging: that write is the only guard prompt of the warp. Done when nothing on the course waits on the user and every approved test is committed red, or the user has said to leave one for mid-flight.
5. **Engage: clear the course**, one ticket at a time and in order. Claim each one with the tracker's Claim operation before any other write.
   - **Away team**: dispatch `away-team` without asking, and close the ticket once its findings are posted. Go on with tickets that don't wait on it.
   - **Probe**: make it and show it. The user's reaction is its answer.
   - **Task**: do it. A task that needs another person, an account or a deploy is an obstacle.
   - **Anomaly** or **probe**: answered in pre-flight. One left for mid-flight is a mid-flight question.
   - **Star**, a target included: start the `do` skill on it with the Skill tool, one `do` run per star, on the warp's branch. `do` is the build: a warp never writes a star's code itself, and `step-guard` refuses a pull request at ready whose do build names no examples. Open pre-flight's pages from a checkout on the warp's branch. Its steps 1 and 2 find the examples approved and the red tests committed by pre-flight, and it goes on at step 3, so its `sentinels` pass and `review` run. Close the star once `do` ends.

   Done when every ticket on the course is closed.
6. **Finish the build.** Run `review` over the whole branch, then `make-it-so`. A warp through several stars passes `make-it-so`'s size item with the body line "A warp through <n> stars, one pull request per effort." Done when the pull request's required checks are green.
7. **Land.** Redraw each chart the course crossed, without the course. Run `loose-ends`. Open the landing report with one sign-off line that drops out of warp, in the voice the session's output style sets ("🖖 Dropped out of warp. <n> stars are Done."). Then give the pull request, each target still open with what keeps it out of reach, and what is left. Done when every ticket the warp touched is settled and the landing report is sent.

**State at every stop.** At every stop, write the pull request body's Status section, as `ship-it` says: a draft opened, a slice parked, a gate reached, the run ended. A ticket whose slice is parked: park its ticket with the tracker's "Park a ticket" action, with a `Waits on:` line, as "Waiting work" in `docs/agents/issue-tracker.md` says.

## Mid-flight questions

A question only the user can answer that turns up after pre-flight never stops the build. Ask it once, with your pick. When no answer comes before the work needs it, take your pick, record it in the pull request's Check these, and fly on. A pick too costly to undo takes one of two courses:

- **Carve a seam** when the target ships without the part the question holds. File that part as its own ticket on the chart, parked on the user with a `Waits on:` line, and narrow the target's body to what remains, the way `loose-ends` narrows a ticket. Build the rest.
- **Stop at an asteroid belt** when the question is one ([STAR-CHART.md](../lay-course/STAR-CHART.md), "Words"). Build around it, gather every such question, and at the end of the course drop out once, among the rocks, to take readings: one round of questions, each with your pick. Their answers re-engage the warp.

## Punch through

An obstacle is anything on the course that waits on someone else, or refuses: an answer, an approval, a merge, a review, a draft in the user's editor, a hook or a permission that says no. Take the first that works:

1. **Clear it with what you hold.** Use every authorization the user and the repo give you: a merge you may make, a bypass the user granted, a route the refusal itself names. Never work around what a refusal exists to stop.
2. **Go around it.** Keep working on everything that doesn't wait on it, but write no code for a star until its approved tests exist and fail (`red-first-guard` backs this): other tickets on the course, the next slice, the other repositories. When the next step builds on the blocked one, build on top of it as a stack with `stacked-branches`: a warp is the user's standing ask for one.
3. **Sit at the gate**, only when nothing else is left and the gate should open soon, as [GATES.md](../../GATES.md) says, waiting with `${CLAUDE_PLUGIN_ROOT}/scripts/watch.sh '<check>'` under the Monitor tool. At a merge or review gate, the check reads the pull request's own state, merged or closed (`gh pr view <n> --json state`, or `tea api repos/{owner}/{repo}/pulls/<n>`), never only CI: the user may merge while you watch. When the watch ends on a gate a pick can open, take your pick, record it in the pull request's Check these, and fly on.

A brief for an agent working a public repository holds it to `loose-lips`' attack-map test, never to a ban on every name: repository names, ticket keys and decision record numbers are navigation.

When the user stops the warp partway, leave each cleared ticket closed and the rest open, and post where it stopped as a comment on the chart, or on each target still open when there is no chart.

Charter: C5, C6 ([CHARTER.md](../../CHARTER.md)).
