# vicky-skills

Claude Code skills for steering coding agents in any repository: wayfinder maps for planning, test-first builds, and reviews on three axes. They're built on ideas from [Matt Pocock's skills](https://github.com/mattpocock/skills), and `ship-it`'s pictures come from Dex Horthy's [show-me](https://github.com/humanlayer/skills). The main addition is approved examples: you approve the examples a build must pass before the agent writes any code.

No skill here shares a name with one of Matt's, so both plugins load without clashing. They describe two different workflows, though, so use one at a time.

- **`lay-course`** plans an effort too big for one session as a map of tickets. Build tickets are one goal, approved examples and pointers.
- **`examples`** turns a ticket, rule or decision into Given / When / Then examples, opens them in your editor, and writes the ones you approve as failing tests.
- **`do`** builds test-first from a request typed in chat, a ticket or a whole map: approved examples go red first, then tests at agreed seams, then mutation. Small work needs no map or ticket.
- **`review`** reviews a branch on three axes at once: standards, spec and simplicity. Each axis is its own agent, and they share one list of review principles: one point of entry, data read from its source, one copy of logic, and tests proved by mutation.
- **`human-voice`** writes anything a person reads in plain language, from a ticket to a public article.
- **`ui-design-101`** designs the actions in an interface for their hundredth use.
- **`over-to-you`** hands the checks only a person can do to you, as a short checklist in your editor with room for notes.
- **`loose-lips`** checks anything leaving the machine for an attack map and rewrites it by role.
- **`robot-voice`** writes skills, agent files and prompts for maximum agentic ergonomics.
- **`plot-twist`** carries a change of direction into every ticket, pull request and doc that still says the old thing.
- **`loose-ends`** settles every ticket an effort touched and keeps the pull request body true.
- **`marie-kondo`** deletes merged branches and worktrees and keeps what sparks joy.
- **`red-pen`** opens drafts in your editor and writes back what you leave.
- **`sup`** catches you up in one screen: done, changed, waiting on you, next.
- **`video-captions`** reads a video through its captions.
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
```

Run both before every push.
