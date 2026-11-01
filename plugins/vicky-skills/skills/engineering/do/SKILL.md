---
name: do
description: Build something behaviour-first, from a sentence in chat, a ticket or a whole star chart. The user approves Given / When / Then examples, each becomes a red test, the code turns them green, and mutation proves the tests catch bugs. Use when the user asks for a change, hands over a ticket, or hands over a star chart to build.
---

# Do

> _Do, or do not. There is no try: red first, then green, then the mutants._

A **build** turns approved examples green. **The examples are the spec, and each one is a seam**: a Given / When / Then its test proves from the observer's side. Prose explains why and decides nothing. Mutation proves the tests can fail. The user brings a request typed in chat, a star, or a star chart whose stars are ready. A request too big for one session goes to `lay-course` instead, and a star with open blockers to `warp`. When a conversation has already settled what to build and it needs tickets, ask the user to type `/mission-brief`.

Read the repo's `TESTING_STANDARDS.md` first: it wins over this skill's defaults. With no such file, the defaults stand.

A **trunk repo** takes every change straight on main: its `CLAUDE.md` or `AGENTS.md` says to commit to `main` and open no branch or pull request. Read the agent file of the repo you will change, even when the session started in another one. In a trunk repo, every step below commits on `main` after `git pull --rebase` and pushes there, with no branch, draft or pull request, and an integration branch is `main` itself.

## Build one change

1. **Get approved examples.** Read the ticket whole, body and comments, the decision records it points at, and the repo's glossary if it has one. When the ticket already holds approved examples, no editor opens: go to step 2. Otherwise run the `examples` skill, which hands its drafts to the user with `red-pen` before any test or code is written. Move the ticket to the started state (In Progress) before the first commit. A request typed in chat is the whole source. Done when every example the build rests on is approved.
2. **Make the examples red.** Write and run their tests as `examples` step 5 says. Done when each approved test fails because the behaviour is missing. Commit them, push the branch and open a **draft** pull request: GitHub's `gh pr create --draft`, or a `WIP:` title prefix on Gitea, unless the repo's guide names another way. A draft asks no one to review it.
3. **Go red to green, one example at a time.** Write only enough code to pass the next approved test ("The smallest complete change" below), then the next. The approved tests are the goal: add any other test that helps you reach it. An edge case the work turns up: add a test, fix the code, and list it as found in the report. Never ask about one. Mutate each example as its test goes green: run `sentinels` on its changed lines, answer each survivor as step 4 says, and show its receipt, with the counts, before you start the next example ("Receipts" below). Never ask the user where a test goes: the example's observer and words pick its seam. A behaviour the code needs that no example covers is a **missing example**: add its draft to the effort's `red-pen` draft file, park that slice, and build the rest. Done when every approved test passes.
4. **Mutate what the per-example passes missed**: the decision logic you changed (rules, limits, parsers) with `sentinels`. Kill each survivor with a test, or mark it equivalent with its reason, and put the counts in the report as proof. A survivor that shows a behaviour no example names is a missing example, as step 3 says. Done when its report line names every file and each survivor has its answer.
5. **Run the checks the change reaches**: the typechecker, and the tests in the files and folders you touched. The repo's docs say whether the full suite runs locally or in CI. Done when they pass.
6. **Review** with the `review` skill. Fix each finding, or record the ones you defer on a ticket. Done when every finding has an answer.
7. **Make it so.** Finish the draft with the `make-it-so` skill. It hands the missing examples to the user, and each one approved goes back through step 2. Done when it reports every required check green.

## No stops from step 3 to step 7

The user may be away once the examples are approved, and a question or an open editor would stall the build until they return. From step 3 on, keep going and hold everything for the end:

- **Drafts**, missing examples included: add each to the effort's `red-pen` draft file. Each player-facing or UI text the build writes or changes is a draft: add its section the moment you write it, and never list it as unread in the pull request body or ask for it in an `over-to-you` item. Write other draft text at its destination and commit it there, unless the repo's guide keeps unread text out of commits: then leave those hunks unstaged until `make-it-so`. Leave the draft file closed.
- **Questions**: A choice that no example settles and that changes no behaviour: take your pick, build on, and name it in the report. For any other, take the answer cheapest to undo, build on it, and add a line to a **Check these** list in the pull request body: the question, your answer, and the commit that holds it.
- **A guess too costly to undo, or an approved example the build shows is wrong**: park that slice. Add it to Check these with what it waits on, and build the rest.

`make-it-so` hands the drafts and the list to the user before the pull request goes ready. Done when step 7 starts with no question asked since step 1.

**State at every stop.** At every stop, write the pull request body's Status section, as `ship-it` says: a draft opened, a slice parked, a gate reached, the run ended. A ticket whose slice is parked: move its ticket back to the not-started state with a `Waits on:` line, as "Waiting work" in `docs/agents/issue-tracker.md` says.

## Receipts

Each time an approved example goes green, show its receipt in chat before you start the next example: the red run, the green run and the mutation result, each as the command and the line that shows its outcome. A receipt is for the user to see, and it asks nothing. An example only a person can check gets a receipt that says `unchecked` and names the `over-to-you` checklist that holds it.

```text
<example name>
red:      <command> → <the failing line>
green:    <command> → <the passing line>
mutation: <command> → <killed>/<mutants>, survivors: <n>
```

## The smallest complete change

Lazy about the solution, never about the change: every caller, test, fixture and doc the change breaks is part of it.

1. **List the reach first**: callers, tests, fixtures, config, exports, and what a user loses if it goes wrong. That list is the scope, and anything outside it is a feature nobody asked for.
2. **Take the first option that fully works**, in this order: not needed at all; a helper, pattern or service the repo already has; the language's standard library; an installed dependency; one line a reader gets at a glance; the least new code.
3. **Deepen, don't spread**: put new behaviour inside the module that owns its concept, behind the interface it already has. A new module passes the deletion test in the review principles.
4. **Add nothing for later**: no abstraction, option, wrapper or layer without a current caller. Keep the repo's structure and the platform's own types.
5. **Fix a bug at its root**: find every caller of what you touch, then fix the shared code once.
6. **Mark a known limit** with a one-line comment, `shortcut: <the limit>, <when to upgrade>`.
7. **End the report** with each approved example with its red run and its green run, then what you skipped or didn't check, and any risk the user must know. An example only a person can check is marked unchecked and handed to `over-to-you` as a checklist. A skipped step names the step, the reason and the proof, also written as `Skipped: <step>, because <reason>` in the pull request body.

Validation at a trust boundary, error handling that prevents data loss, security and accessibility are never cut.

## Tests worth keeping

- A test goes through a public interface and survives a refactor that keeps behaviour.
- Mock only at the system's edges: the network, the clock, randomness, a service you don't own. Your own modules run for real.
- A test that can only go red on a refactor, a content edit or a library upgrade proves nothing (`placebo` lists the shapes).
- Refactor during review, never inside the red-to-green loop.

## Build a whole star chart

The frontier is every open, unblocked star on the chart.

1. Create one **integration branch** for the chart. Open its draft pull request after the first merge, closing every star. Done when the branch exists and its draft pull request is open.
2. Give each frontier ticket to its own implementer subagent, in its own worktree, on a branch from the integration branch. Each one runs steps 1 to 5 above with no stops, reports its drafts and Check these lines, then brings the integration branch into its own before it reports. Done when each implementer has reported.
3. Merge each finished branch into the integration branch. When that opens new frontier tickets, start their subagents. Done when no open unblocked star is left without a subagent or a merge.
4. Once every ticket is done, run step 6 on the integration branch and fix its findings in one more subagent.
5. Remove every worktree the build made, then finish with `make-it-so`. Done when `git worktree list` shows none of them and `make-it-so` reports green.
