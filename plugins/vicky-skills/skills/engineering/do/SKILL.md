---
name: do
description: Build something test-first, from a sentence in chat, a ticket or a whole map. Approved examples go red first, tests follow at agreed seams, and mutation proves the tests catch bugs. Use when the user asks for a change, hands over a ticket, or hands over a map to build.
---

# Do

A **build** turns approved examples green. The examples are the contract, the tests below them are the agent's own, and mutation proves those tests can fail. The user brings a request typed in chat, a build ticket, or a map whose build tickets are ready. A request too big for one session goes to `lay-course` instead.

## Build one change

1. **Read** the ticket whole, body and comments, the decision records it points at, and the repo's glossary if it has one. A request typed in chat has no ticket: play it back in one sentence and get the user's yes. Done when you can say what the build makes true in one sentence.
2. **Make the examples red.** Without approved examples, run the `examples` skill first. Write and run their tests as its step 5 says. Done when each approved test fails because the behaviour is missing.
3. **Agree the seams.** A **seam** is the public boundary where a test watches behaviour without reaching inside. Name the seams you will test at and confirm them with the user. Prefer an existing seam to a new one, and the highest one the repo's testing rules allow. Done when the user has agreed the list.
4. **Go red to green, one slice at a time.** Before each test, write its **intent** in one line: "holds <behaviour>; turns red when <production change>". No such change, no test: a test that can only go red on a refactor, a content edit or a library upgrade proves nothing (`placebo` lists the shapes). Then write the failing test at an agreed seam, only enough code to pass it, and the next. Each test takes its expected value from an independent source: an approved example, a worked example or a known literal, never a recomputation of what the code does. Done when every approved test passes.
5. **Mutate.** Run the mutation tool the repo's docs name on the decision logic you changed (rules, limits, parsers). Answer each surviving mutant with a test that kills it, the deletion of the code it lived in, or a comment saying why no input tells it apart. Where the repo has no mutation tool, say so in the pull request. Done when no survivor is unanswered.
6. **Run the checks the change reaches**: the typechecker, and the tests in the files and folders you touched. The repo's docs say whether the full suite runs locally or in CI. Done when they pass.
7. **Review** with the `review` skill. Fix each finding, or record the ones you defer on a ticket. Done when every finding has an answer.

## Tests worth keeping

- A test goes through a public interface and survives a refactor that keeps behaviour.
- Mock only at the system's edges: the network, the clock, randomness, a service you don't own. Your own modules run for real.
- A test written after the code it tests, or recomputing its expected value the way the code does, can only agree with the code. Write the test first.
- Write one test, then its code. A batch of tests written up front tests imagined behaviour.
- Refactor during review, never inside the red-to-green loop.

## Build a whole map

The frontier is every open, unblocked build ticket on the map.

1. Create one **integration branch** for the map. Open its pull request after the first merge, closing every build ticket.
2. Give each frontier ticket to its own implementer subagent, in its own worktree, on a branch from the integration branch. Each one runs steps 1 to 6 above, then brings the integration branch into its own before it reports.
3. Merge each finished branch into the integration branch. When that opens new frontier tickets, start their subagents.
4. Once every ticket is done, run step 7 on the integration branch and fix its findings in one more subagent.
5. Mark the pull request ready, and remove every worktree the build made.
