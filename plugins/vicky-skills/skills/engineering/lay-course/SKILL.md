---
name: lay-course
description: The lazy front door for a session that doesn't know where it leads. A council or an interrogation finds what you want, the stars get placed as a star chart or one star, and then it stops or engages warp. Use with a loose idea to start, or with a star chart to work through.
disable-model-invocation: true
---

# Lay course

> _Lay in a course. Place the stars before you engage: warp flies only to a star on the chart._

`lay-course` starts a session whose end you don't know yet. It places the **stars**, as a **star chart** or one star, then stops or engages `warp`. Work the user already understands goes to `do` instead.

The words, the chart body, the ticket forms and the drawing are in [STAR-CHART.md](STAR-CHART.md): read it before the first write. The tracker is named in `docs/agents/issue-tracker.md`, and its "Star chart operations" section says how this repo expresses children, blocking, the frontier and an attached chart. If the file is missing, tell the user to run `/first-contact`.

## Start an effort

The user brings a loose idea. When they bring the result of a council or an interrogation instead, start at step 4.

1. **Pick the method.** Ask once: "Council, where we argue ideas, or interrogation, where you answer questions?" The council is `council-of-elrond`, the easy mode. Interrogation is `interrogation`, the hard mode, which makes the user say what they want. Done when the user has picked one.
2. **Name the mission** with that method and `true-names`. Done when the user agrees to a mission of at most three sentences.
3. **Find the frontier** with that method, breadth-first across the whole idea. Done when every open question can be stated as a ticket or is a nebula.
4. **Place the stars.** Propose one, and wait for the user's yes:
   - **A nebula, or more than one session of work**: a star chart. Go on to step 5.
   - **One session of work**: one star, written by `examples` up to its Record step. Go on to step 7.

   Done when the user has taken one or named another.
5. **Create the chart** with Mission, Prime directive, Sensor log and Nebulae filled in. Create the anomalies, away teams, probes, tasks and stars you can state now as its children. Wire blocking in a second pass, once every ticket has a key. Draw the chart. Done when the chart shows every child and every blocker.
6. **Dispatch one `away-team` subagent per away team ticket.** Done when each one is running.
7. **Engage or stop.** Ask: "Warp to <star> now, or stop here?" For a chart, propose the star the user's idea was about. On "warp", run `warp` on that star. Done when `warp` is running or the user has said stop.

## Work the chart

The user brings a star chart, and maybe a ticket. Resolve one anomaly per session. Away teams are the exception, and so is a council, which may settle several of the chart's tickets at once. When the user names a star to reach, run `warp` instead.

1. **Load the chart body.** Read other tickets only when the work needs them.
2. **Pick the ticket**: the user's, or the first on the frontier. Assign it to the user before any other work.
3. **Resolve it** with the skills its kind names. For an anomaly, ask the method first (Start an effort, step 1). A council resolves every ticket its settled points answer. Done when the question has an answer the human gave or the evidence supports.
4. **Record it.** Post the answer as a comment and close the ticket. Write a decision record when the answer will outlast the chart. Add its line under Decisions, with the method that answered it.
5. **Move the chart forward.** Turn a nebula that is now sharp into tickets. When a decision makes a star specifiable, file it and run `examples` for it. Close a ticket the answer puts past the mission, with its line under Neutral zone. Update or close any ticket the answer makes wrong. Redraw the chart. Done when every line of the chart body is true.

Other sessions may work the same chart, so read the tracker again before each write.
