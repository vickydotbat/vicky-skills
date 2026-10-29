---
name: do
description: Build something test-first, from a sentence in chat, a ticket or a whole map. Approved examples go red first, tests follow at agreed seams, and mutation proves the tests catch bugs. Use when the user asks for a change, hands over a ticket, or hands over a map to build.
---

# Do

A **build** turns approved examples green. The examples are the contract, the tests below them are the agent's own, and mutation proves those tests can fail. The user brings a request typed in chat, a build ticket, or a map whose build tickets are ready. A request too big for one session goes to `lay-course` instead.

## Build one change

1. **Read** the ticket whole, body and comments, the decision records it points at, and the repo's glossary if it has one. A request typed in chat has no ticket: play it back in one sentence and get the user's yes. Done when you can say what the build makes true in one sentence.
2. **Make the examples red.** Without approved examples, run the `examples` skill first. Write and run their tests as its step 5 says. Done when each approved test fails because the behaviour is missing. Commit them, push the branch and open a **draft** pull request: GitHub's `gh pr create --draft`, or a `WIP:` title prefix on Gitea, unless the repo's guide names another way. A draft asks no one to review it.
3. **Agree the seams.** A **seam** is the public boundary where a test watches behaviour without reaching inside. Name the seams you will test at and confirm them with the user. Prefer an existing seam to a new one, and the highest one the repo's testing rules allow. Done when the user has agreed the list.
4. **Go red to green, one slice at a time.** Before each test, write its **intent** in one line: "holds <behaviour>; turns red when <production change>". No such change, no test: a test that can only go red on a refactor, a content edit or a library upgrade proves nothing (`placebo` lists the shapes). Then write the failing test at an agreed seam, only enough code to pass it ("The smallest complete change" below), and the next. Each test takes its expected value from an independent source: an approved example, a worked example or a known literal, never a recomputation of what the code does. Done when every approved test passes.
5. **Mutate** the decision logic you changed (rules, limits, parsers) with `sentinels`. Done when its report line names every file and no survivor is unanswered.
6. **Run the checks the change reaches**: the typechecker, and the tests in the files and folders you touched. The repo's docs say whether the full suite runs locally or in CI. Done when they pass.
7. **Review** with the `review` skill. Fix each finding, or record the ones you defer on a ticket. Done when every finding has an answer.
8. **Make it so.** Finish the draft with the `make-it-so` skill. Done when it reports every required check green.

## No stops from step 4 to step 8

The user may be away once the seams are agreed, and a question or an open editor would stall the build until they return. From step 4 on, keep going and hold everything for the end:

- **Drafts**: add each to the effort's `red-pen` draft file and write the draft text at its destination. Commit it there unless the repo's guide keeps unread text out of commits: then leave those hunks unstaged until `make-it-so`. Leave the draft file closed.
- **Questions**: take the answer cheapest to undo, build on it, and add a line to a **Check these** list in the pull request body: the question, your answer, and the commit that holds it.
- **A guess too costly to undo, or an approved example the build shows is wrong**: park that slice. Add it to Check these with what it waits on, and build the rest.

`make-it-so` hands the drafts and the list to the user before the pull request goes ready. Done when step 8 starts with no question asked since step 3.

## The smallest complete change

Lazy about the solution, never about the change: every caller, test, fixture and doc the change breaks is part of it.

1. **List the reach first**: callers, tests, fixtures, config, exports, and what a user loses if it goes wrong. That list is the scope, and anything outside it is a feature nobody asked for.
2. **Take the first option that fully works**, in this order: not needed at all; a helper, pattern or service the repo already has; the language's standard library; an installed dependency; one line a reader gets at a glance; the least new code.
3. **Add nothing for later**: no abstraction, option, wrapper or layer without a current caller. Keep the repo's structure and the platform's own types.
4. **Fix a bug at its root**: find every caller of what you touch, then fix the shared code once.
5. **Mark a known limit** with a one-line comment, `shortcut: <the limit>, <when to upgrade>`.
6. **End the report** with what you skipped or didn't check, and any risk the user must know.

Validation at a trust boundary, error handling that prevents data loss, security and accessibility are never cut.

## Tests worth keeping

- A test goes through a public interface and survives a refactor that keeps behaviour.
- Mock only at the system's edges: the network, the clock, randomness, a service you don't own. Your own modules run for real.
- A test written after the code it tests, or recomputing its expected value the way the code does, can only agree with the code. Write the test first.
- Write one test, then its code. A batch of tests written up front tests imagined behaviour.
- Refactor during review, never inside the red-to-green loop.

## Build a whole map

The frontier is every open, unblocked build ticket on the map.

1. Create one **integration branch** for the map. Open its draft pull request after the first merge, closing every build ticket.
2. Give each frontier ticket to its own implementer subagent, in its own worktree, on a branch from the integration branch. Each one runs steps 1 to 6 above with no stops, reports its drafts and Check these lines, then brings the integration branch into its own before it reports.
3. Merge each finished branch into the integration branch. When that opens new frontier tickets, start their subagents.
4. Once every ticket is done, run step 7 on the integration branch and fix its findings in one more subagent.
5. Remove every worktree the build made, then finish with `make-it-so`.
