# vicky-skills

Claude Code skills for steering coding agents in any repository: wayfinder maps for planning, test-first builds, and reviews on three axes. They're built on ideas from [Matt Pocock's skills](https://github.com/mattpocock/skills), and `pr`'s pictures come from Dex Horthy's [show-me](https://github.com/humanlayer/skills). The main addition is approved examples: you approve the examples a build must pass before the agent writes any code.

Install this plugin instead of Matt's, not beside it. Both have a `handoff`, a `retro` and so on, and an agent can't tell two skills with the same name apart.

- **`lay-course`** plans an effort too big for one session as a map of tickets. Build tickets are one goal, approved examples and pointers.
- **`examples`** turns a ticket, rule or decision into Given / When / Then examples, opens them in your editor, and writes the ones you approve as failing tests.
- **`do`** builds a ticket or a whole map: approved examples go red first, then tests at agreed seams, then mutation.
- **`review`** reviews a branch on three axes at once: standards, spec and simplicity. Each axis is its own agent, and they share one list of review principles: one point of entry, data read from its source, one copy of logic, and tests proved by mutation.
- **`human-voice`** writes anything a person reads in plain language, from a ticket to a public article.
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

The hook only sees edits made through Claude Code's own edit tools. Back it with a CI check in each repository that fails a pull request changing an `approved-spec` file without your approval.

The idea is acceptance test-driven development. Dave Farley's [The Industry Is Catching Up](https://www.youtube.com/watch?v=EkH_uoybj8k) is the best short case for it.

## Development

```bash
claude plugin validate .
tests/approved-spec-guard.test.sh
```

Run both before every push.
