---
name: do
description: Build something behaviour-first, from a sentence in chat, a ticket or a whole star chart. Use when the user asks for a change, hands over a ticket, or hands over a star chart to build.
---

# Do

> _Do, or do not. There is no try: red first, then green, then the mutants._

A **build** turns approved examples green, behaviour first: every behaviour change it lands, asked for or found, has a test that went red before the code (`red-first-guard` holds the approved ones). **The examples are the spec, and each one is a seam**: a Given / When / Then its test proves from the observer's side. Prose explains why and decides nothing. Mutation proves the tests can fail. The user brings a request typed in chat, a star, or a star chart whose stars are ready. A request too big for one session goes to `lay-course` instead, and a star with open blockers to `warp`. When a conversation has already settled what to build and it needs tickets, run `mission-brief`.

Read the repo's `TESTING_STANDARDS.md` first: it wins over this skill's defaults.

A **trunk repo** takes every change straight on main: its `CLAUDE.md` or `AGENTS.md` says to commit to `main` and open no branch or pull request. Read the agent file of the repo you will change, even when the session started in another one. In a trunk repo, every step below commits on `main` after `git pull --rebase` and pushes there, with no branch, draft or pull request, and an integration branch is `main` itself. Outside a trunk repo, the `git-guard` hook refuses a push to main and a new branch stacked on unmerged work, and `checkout-guard` keeps two sessions out of one checkout: build in your own worktree.

Before every push, run `git fetch` and rebase the branch onto the remote's default branch with `history-monks`: `push-behind-guard` refuses a push from behind it.

## Build one change

0. **Confirm the objective**, only when the user typed the objective in chat and you read it into their words, from a question or a hedge ("maybe", "could we"): no ticket, chart or warp names it. An objective their words state in full is taken: say "Going with: <the objective>" in one line and go on to step 1. Your first message is a gate, as [GATES.md](../../GATES.md) says: say the objective back in one line, with the reason you read behind it, and build nothing until the user answers. A wrong objective is the guess that costs most to undo, so this gate carries no pick and, unanswered, ends parked. Only this first question waits: every later choice that is cheap to undo takes its pick and says "Going with". Done when the user has confirmed or corrected the objective, or the work is parked with a `Waits on:` line.
1. **Get approved examples.** Read the ticket whole, body and comments, the decision records it points at, and the repo's glossary if it has one. A star's chart binds it: read the chart whole too, body and comments, and treat its Prime directive and Sensor log as premises. When the ticket already holds approved examples ticked on a page opened from this branch, no editor opens: write the line `Examples: approved on <ticket>` in a reply and go to step 2. Code waits for the tick itself, never for that line: `do-first-guard` reads the record the page writes for the branch when the user ticks. Otherwise run the `examples` skill, which hands its drafts to the user with `red-pen` before any test or code is written, from a checkout on the build's branch. Move the ticket to the started state (In Progress) before the first commit. A request typed in chat is the whole source. A chat reply is never an approval, so no test or code is written until the page comes back with each example ticked. A test the human never has to decide (`examples`' "Approval is for what the human asks for or designs") skips the page: write the line `Examples: none, because <reason>` and write it red as step 3 says. Behaviour the user requested always needs approved examples first. Found work (a review finding, a bug a test caught) needs no approval, but its example is drafted before the build: write `Examples: none, because found work: <what>`, with its Given, When and Then lines under it, and list it under Tested unasked in the report. Done when every example the build rests on is approved.
2. **Make the examples red.** First run the **plan check**, whatever familiar the user keeps: argue against the plan before the first test or line of code. Name each rule the user stated in this effort that the plan breaks, and the clash, then change the plan or ask the user. Read and quote each file, setting or branch the plan rests on that nobody read this session. When the build ports a feature that already runs elsewhere, and the chart's Prime directive, a pointer or the user names that source, read its implementation first, and quote what the plan takes from it and where it differs. A pass that finds nothing asks nothing and builds on. Either way, write one `Plan check: <what it found>` line in the pull request body. `step-hint` repeats this when `do` starts. When a warp's pre-flight already committed them red, this step is done: go to step 3. Otherwise write and run their tests as `examples` step 5 says. Done when the plan check has its line and each approved test fails because the behaviour is missing. Commit them and push the branch. When an open pull request already holds the work you build on (this branch's, the one the user names, or the warp's), the build goes there: commit and push to its branch, and open nothing new. Otherwise open a **draft** pull request with `ship-it`, which writes its body: GitHub's `gh pr create --draft`, or a `WIP:` title prefix on Gitea, unless the repo's guide names another way. A draft asks no one to review it.
3. **Go red to green, one example at a time.** Before each red and each green run of an example's test, write your prediction: pass or fail, and for a fail the line or reason it fails on. When a run differs from the prediction, stop that example and find the cause with `never-lupus` before you change any code: an unexpected pass or the wrong failure means the test or your model of the code is wrong. Write only enough code to pass the next approved test ("The smallest complete change" below), then the next. The approved tests are the goal: add any other test that helps you reach it. Each toggle the build adds (a fold, a collapse, a mode) gets a test that flips it, closes and reopens the window, and flips it back, since saved state survives the close. A behaviour that comes as a pair (draw and holster, open and close, enter and leave) gets a test for each half before the hand-over, since the event that starts one half may have no partner event for the other. An edge case the work turns up: add a test, fix the code, and list it as found in the report. Never ask about one. A regression, or a fix that restores a rule the user stated, gets the same: its test red first, listed under Tested unasked. Mutate each example as its test goes green: run `sentinels` on its changed lines, answer each survivor as step 4 says, and show its receipt, with the counts, before you start the next example ("Receipts" below). When the example is something the user sees on a page, run `by-eye` on it before the next example. A window by-eye can't open, such as a game client's, is reported only as built and waiting on the user's look, never as how it looks. Never ask the user where a test goes: the example's observer and words pick its seam. A behaviour the code needs that no example covers is a **missing example**: add its draft to the effort's `red-pen` draft file, park that slice, and build the rest. Done when every approved test passes.
4. **Mutate what the per-example passes missed**: the decision logic you changed (rules, limits, parsers) with `sentinels`. `sentinels` is never skipped by a written line, whatever the file kind. Kill each survivor with a test, or mark it equivalent with its reason, and put the counts in the report as proof. When the repo's `docs/agents/testing.md` has a `Mutation proof refresh:` line, run that command on the files it covers in this step, before any commit, and commit the proof it writes with the change: `mutation-proof-guard` refuses a commit whose proof is stale. A survivor that shows a behaviour no example names is a missing example, as step 3 says. Then **metrics**, when `TESTING_STANDARDS.md` has a `Metrics:` line that isn't `none`: for each rule the change sets with a target written where that line says, run what it names and post the report on the rule's ticket. When the line says a person runs it, add `Metrics owed: <rule>` to the pull request body instead and keep going. A metric is a report and never a gate: no number it gives passes, fails or changes the code. Done when its report line names every file, each survivor has its answer, and each rule with a written target has its metrics on its ticket or a `Metrics owed:` line.
5. **Run the checks the change reaches**: the typechecker, and the tests in the files and folders you touched. The repo's docs say whether the full suite runs locally or in CI. A proof that lives outside the repo that ships the change (a workbench, a notebook, a journal entry) is ported into it as a test in this step, or the pull request's Status section says why not. When the change needs a hand check, start `over-to-you` in the same turn: its page opens and its 🚪 line goes out before the turn ends, never in a later reply. Done when they pass.
6. **Review** with the `review` skill, as the build's last step, over the commits this build made: its fixed point is the commit the branch stood on before this build's first commit (`git merge-base HEAD origin/<default>` on a fresh branch, the head you started from on an open pull request or in a trunk repo). Fix each finding in the same pull request. Only a finding that waits on the user's decision, another person, a deploy or a repo out of reach goes on a ticket, with a `Waits on:` line. Done when every finding has an answer.

## No stops from step 3 to step 6

The user may be away once the examples are approved, and a question or an open editor would stall the build until they return. From step 3 on, keep going and hold everything for the end:

- **Drafts**, missing examples included: add each to the effort's `red-pen` draft file. Each player-facing or UI text the build writes or changes is a draft: add its section the moment you write it, and never list it as unread in the pull request body or ask for it in an `over-to-you` item. Write other draft text at its destination and commit it there, unless the repo's guide keeps unread text out of commits: then leave those hunks unstaged until `make-it-so`. Leave the draft file closed.
- **Questions**: A choice whose options differ in how something looks carries an image of each option; make the images first. Before you ask, check the rules the user stated in this effort, and its approved examples: a case one of them covers is no question, so apply it and name the rule in the report. A recommendation that rests on the state of a store (a depot, a tracker, a remote, a registry) is a premise: the agent reads that store first, and quotes what it holds beside the advice. A choice that no example settles and that changes no behaviour: take your pick, build on, and name it in the report. For any other, take the answer cheapest to undo, build on it, and add a line to a **Check these** list in the pull request body: the question, your answer, and the commit that holds it.
- **Commit messages** name only the checks that ran before the commit. A check still to come goes in the pull request's Status section.
- **Shared stores**: an upload to a store others pull from (a depot, CDN, registry, package index or release) happens once per effort, when the change is complete and proven through a local override. Every fix before then is tested locally, never uploaded.
- **A guess too costly to undo, or an approved example the build shows is wrong**: park that slice. Add it to Check these with what it waits on, and build the rest.

`make-it-so`, run by `warp` or when the ask needs a finished pull request, hands the drafts and the list to the user before the pull request goes ready. Done when step 6 ends with no question asked since step 1.

**State at every stop.** At every stop, write the pull request body's Status section, as `ship-it` says: a draft opened, a slice parked, a gate reached, the run ended. A ticket whose slice is parked: park its ticket with the tracker's "Park a ticket" action, with a `Waits on:` line, as "Waiting work" in `docs/agents/issue-tracker.md` says.

## Receipts

Each time an approved example goes green, show its receipt in chat before you start the next example: each prediction above its run, the red run, the green run and the mutation result, each as the command and the line that shows its outcome. A receipt is for the user to see, and it asks nothing. An example only a person can check gets a receipt that says `unchecked` and names the `over-to-you` checklist that holds it.

```text
<example name>
predicted red:   <fail, and the line or reason it fails on>
red:      <command> → <the failing line>
predicted green: <pass>
green:    <command> → <the passing line>
mutation: <command> → <killed>/<mutants>, survivors: <n>
```

## The smallest complete change

Lazy about the solution, never about the change: every caller, test, fixture and doc the change breaks is part of it.

1. **List the reach first**: callers, tests, fixtures, config, exports, and what a user loses if it goes wrong. That list is the scope, and anything outside it is a feature nobody asked for.
2. **Take the first option that fully works**, in this order: not needed at all; a helper, pattern or service the repo already has; the language's standard library; an installed dependency; one line a reader gets at a glance; the least new code.
3. **Deepen, don't spread**: put new behaviour inside the module that owns its concept, behind the interface it already has. A new module passes the deletion test in the review principles.
4. **Add nothing for later**: no abstraction, option, wrapper or layer without a current caller. Keep the repo's structure and the platform's own types.
5. **Fix a bug at its root**: make the bad state impossible, as the design moves in [PRINCIPLES.md](../review/PRINCIPLES.md) teach, before you handle it downstream. Build new code with those moves too. Find every caller of what you touch, then fix the shared code once.
6. **Edit by exact text, never by a searched position.** A scripted edit replaces one exact passage and checks it matched once. A splice between two searched offsets lands on the first match anywhere in the file: one duplicated and mangled a whole include.
7. **Mark a known limit** with a one-line comment, `shortcut: <the limit>, <when to upgrade>`. Every other comment follows [PRINCIPLES.md](../review/PRINCIPLES.md)'s "A comment is a one-line why".
8. **End the report** with each approved example with its red run and its green run, then each test under Tested unasked with its red and green run, then what you skipped or didn't check, and any risk the user must know. An example only a person can check is marked unchecked and handed to `over-to-you` as a checklist. A skipped step names the step, the reason and the proof, also written as `Skipped: <step>, because <reason>` in the pull request body.

Validation at a trust boundary, error handling that prevents data loss, security and accessibility are never cut.

Keep the build loop in the main thread: each run turns up what the next step needs, and a handoff loses it. Hand a slice to a subagent only when one number or one artifact checks its result: a census, a passing filter, a filed ticket key. Check that number yourself when it comes back.

## Tests worth keeping

- A test goes through a public interface and survives a refactor that keeps behaviour.
- Mock only at the system's edges: the network, the clock, randomness, a service you don't own. Your own modules run for real.
- A test that can only go red on a refactor, a content edit or a library upgrade proves nothing (`placebo` lists the shapes).
- Refactor during review, never inside the red-to-green loop.

## Build a whole star chart

Read [STAR-CHART-BUILD.md](STAR-CHART-BUILD.md) before the first step of a whole-chart build. A single star skips it.

Charter: C1, C2, C4, C5, C6 ([CHARTER.md](../../CHARTER.md)).
