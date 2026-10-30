# vicky-skills

Claude Code skills for steering coding agents in any repository: wayfinder maps for planning, test-first builds, and reviews on three axes. They're built on ideas from [Matt Pocock's skills](https://github.com/mattpocock/skills), `ship-it`'s pictures come from Dex Horthy's [show-me](https://github.com/humanlayer/skills), and `do`'s smallest-change rules from [ponytail](https://github.com/DietrichGebert/ponytail). The main addition is approved examples: you approve the examples a build must pass before the agent writes any code.

No skill here shares a name with one of Matt's, so both plugins load without clashing. They describe two different workflows, though, so use one at a time.

- **`power-word-fix`**: type `/power-word-fix <what's broken>` and it sorts the problem, runs the skills that fit and ends on proof.
- **`lay-course`** starts any effort, big or small. You pick a council or an interrogation to work out what you want, and it ends as a map of tickets, one build ticket, or a build right away. Every build's spec is its approved examples.
- **`examples`** turns a ticket, rule or decision into Given / When / Then examples, opens them in your editor, and writes the ones you approve as failing tests.
- **`do`** builds test-first from a request typed in chat, a ticket or a whole map: approved examples go red first, then tests at agreed seams, then mutation. Small work needs no map or ticket.
- **`review`** reviews a branch on three axes at once: standards, spec and simplicity. Each axis is its own agent, and a diff under 40 lines gets one quick pass instead. They share one list of review principles: one point of entry, data read from its source, one copy of logic, and tests proved by mutation.
- **`human-voice`** writes anything a person reads in plain language, from a ticket to a public article.
- **`ui-design-101`** designs the actions in an interface for their hundredth use.
- **`over-to-you`** hands the checks only a person can do to you, as a short checklist in your editor with room for notes.
- **`loose-lips`** checks anything leaving the machine for an attack map and rewrites it by role.
- **`robot-voice`** writes skills, agent files and prompts for maximum agentic ergonomics.
- **`plot-twist`** carries a change of direction into every ticket, pull request and doc that still says the old thing.
- **`make-it-so`** finishes a draft pull request: current with main, one light QA pass, a true body, marked ready, then CI watched until it's green.
- **`loose-ends`** settles every ticket an effort touched and keeps the pull request body true.
- **`marie-kondo`** deletes merged branches and worktrees and keeps what sparks joy.
- **`red-pen`** opens drafts in your editor and writes back what you leave.
- **`cerebro`** reads why you asked a question about your agent setup, answers it, and proposes the matching changes to its skills and agent files before you have to ask for them.
- **`council-of-elrond`** puts your idea in front of a table of designers. A skeptic, a dwarf with an axe, an elf who looks far ahead, a ranger who walks it through, a rules keeper, an enthusiast and two troublemakers with new ideas argue it with you, whether it's a game rule, a character build or a piece of code. The chair and the rules keeper speak every round, and the rest take turns, so you hear every voice at least every other round. Each round ends on open points, each with a pick, and the council ends by picking the road: a map, one ticket, or a build right now. The agent starts one when you ask for it, pick it in `lay-course`, or bring a design question you haven't answered yet.
- **`sup`** catches you up in one screen: done, changed, waiting on you, next.
- **`history-monks`** rebases a branch onto a main that moved: what landed owns the form, the branch keeps its behaviour, and the old patterns a merge hides get converted too.
- **`sentinels`** mutation-tests changed code with the repo's tool, a tool pulled down for the run, or by hand, and keeps a run alive under a memory cap.
- **`placebo`** audits a test suite for tests that look like proof and catch nothing, and deletes, merges or rewrites them.
- **`retcon`** undoes exactly what you name, and leaves every other change alone.
- **`video-captions`** reads a video through its captions.
- **`is-this-a-meme`** (typed only): `/is-this-a-meme <thing>` explains it, then lands it with a meme. The `dungeon-master` style memes on its own, and nothing else does.
- **The `dungeon-master` output style**: relaxed, focused and exact. The answer first, the next action last, a register per topic, and memes when an idea needs to land. Pick it with `/output-style vicky-skills:dungeon-master`.
- **A guard hook** asks you before an agent edits approved examples: a file named `...ApprovedExamples` or holding a test marked `approved-spec`. It needs `jq`.

## Install

In a Claude Code session:

```
/plugin marketplace add vickydotbat/vicky-skills
/plugin install vicky-skills@vicky-skills
```

To offer it to everyone who works in a repository, run this once from that repository and commit the `.claude/settings.json` it writes:

```bash
claude plugin marketplace add vickydotbat/vicky-skills --scope project
```

Turn on auto-update under `/plugin`, then **Marketplaces**. The plugin has no version number, so every commit to `main` is an update.

## Approved examples

An example says what the game or app does, in its own words, with no code in it:

> Given a creature charmed by another, when its charmer hits it, then the charm ends.

The agent drafts examples, but only the ones you approve become tests, and each test must fail before the code exists. The full rules for a good example are in the `examples` skill.

The hook only sees edits made through Claude Code's own edit tools. Back it in each repository with a merge gate: a code-owner rule that names you for files ending `ApprovedExamples`, or a CI check that refuses a change to one without your approval.

The idea is acceptance test-driven development. Dave Farley's [The Industry Is Catching Up](https://www.youtube.com/watch?v=EkH_uoybj8k) is the best short case for it.

## Development

```bash
claude plugin validate .
tests/approved-spec-guard.test.sh
tests/plugin-layout.test.sh
```

Run all three before every push. CI runs the two tests on every pull request.
