# vicky-skills

Claude Code skills for steering coding agents in any repository: star charts for planning, test-first builds, and reviews on three axes. They're built on ideas from [Matt Pocock's skills](https://github.com/mattpocock/skills), `ship-it`'s pictures come from Dex Horthy's [show-me](https://github.com/humanlayer/skills), and `do`'s smallest-change rules from [ponytail](https://github.com/DietrichGebert/ponytail). The main addition is approved examples: you approve the examples a build must pass before the agent writes any code.

No skill here shares a name with one of Matt's, so both plugins load without clashing. They describe two different workflows, though, so use one at a time.

| Skill | What it does |
| --- | --- |
| `first-contact` | Typed only: `/first-contact` sets a repository up for these skills, once: where its tickets, glossary and decision records are. |
| `power-word-fix` | Typed only: `/power-word-fix <what's broken>` sorts the problem, runs the skills that fit and ends on proof. |
| `lay-course` | Typed only. the lazy way in when you don't know where a session leads. You pick a council or an interrogation to work out what you want. It files a star chart of tickets, or a single ticket (a star) when the work fits in a session, and then stops or warps to it. Every star's spec is its approved examples. |
| `warp` | Gets one star done in a single run. It clears every open question blocking the star, stopping only for the ones you have to answer, then builds it through to green CI. |
| `examples` | Turns a ticket, rule or decision into Given / When / Then examples, opens them in your editor, and writes the ones you approve as failing tests. |
| `do` | Builds test-first from a request typed in chat, a ticket or a whole star chart: approved examples go red first, then tests at agreed seams, then mutation. Small work needs no chart or ticket. |
| `review` | Reviews a branch on three axes at once: standards, spec and simplicity. Each axis is its own agent, and a diff under 40 lines gets one quick pass instead. They share one list of review principles: one point of entry, data read from its source, one copy of logic, and tests proved by mutation. |
| `never-lupus` | Finds the cause of a hard bug or a slowdown with a loop that goes red on it. |
| `ship-it` | Writes a pull request body, and rewrites it when a push changes what the pull request does. |
| `machine-spirit` | Writes and debugs CI: workflows, path filters, runners, caches, required checks, and runs that are red, slow or stuck. |
| `stacked-branches` | Builds and merges a stack of dependent pull requests with `gh stack` or `git-spice`, once you ask for a stack. |
| `human-voice` | Writes anything a person reads in plain language, from a ticket to a public article. |
| `ui-design-101` | Designs the actions in an interface for their hundredth use. |
| `over-to-you` | Hands the checks only a person can do to you, as a short checklist in your editor with room for notes. |
| `loose-lips` | Checks anything leaving the machine for an attack map and rewrites it by role. |
| `robot-voice` | Writes skills, agent files and prompts for maximum agentic ergonomics. |
| `plot-twist` | Carries a change of direction into every ticket, pull request and doc that still says the old thing. |
| `make-it-so` | Finishes a draft pull request: current with main, a QA checklist where a command or one read decides each item, a true body, marked ready, then CI watched until it's green. |
| `loose-ends` | Settles every ticket an effort touched and keeps the pull request body true. |
| `marie-kondo` | Deletes merged branches and worktrees and keeps what sparks joy. |
| `red-pen` | Opens drafts in your editor and writes back what you leave. |
| `cerebro` | Reads why you asked a question about your agent setup, answers it, and proposes the matching changes to its skills and agent files before you have to ask for them. |
| `council-of-elrond` | Puts your idea in front of a table of designers. A skeptic, a dwarf with an axe, an elf who looks far ahead, a ranger who walks it through, a rules keeper, an enthusiast and two troublemakers with new ideas argue it with you, whether it's a game rule, a character build or a piece of code. The chair and the rules keeper speak every round, and the rest take turns, so you hear every voice at least every other round. Each round ends on open points, each with a pick, and the council ends by picking the road: a star chart, one star, or a warp right now. Once it starts, every reply comes from the seats, answers to your questions included. The agent starts one when you ask for it, pick it in `lay-course`, or bring a design question you haven't answered yet. |
| `interrogation` | Is the council's hard mode: it asks you questions only, the sharpest first, until nothing is left open, and writes your answers as examples. |
| `true-names` | Sharpens a project's terms in its glossary and records decisions as you make them. |
| `away-team` | Answers a question from primary sources in a background agent and posts the findings on the ticket the question belongs to. |
| `sup` | Catches you up in one screen: done, changed, waiting on you, next. |
| `you-have-the-conn` | Typed only: `/you-have-the-conn` writes a handoff so a fresh session can pick up where this one stopped. Every claim in it names the command that proved it. |
| `captains-log` | Typed only: `/captains-log` runs a retrospective on a session and finds what would make the next one go better. |
| `history-monks` | Rebases a branch onto a main that moved: what landed owns the form, the branch keeps its behaviour, and the old patterns a merge hides get converted too. |
| `sentinels` | Mutation-tests changed code with the repo's tool, a tool pulled down for the run, or by hand, and keeps a run alive under a memory cap. |
| `placebo` | Lists the kinds of test that look like proof and catch nothing, and the agent checks every test it writes or reviews against them. Ask it for an audit and it deletes, merges or rewrites them across a suite. |
| `retcon` | Undoes exactly what you name, and leaves every other change alone. |
| `video-captions` | Reads a video through its captions. |
| `codex-image-gen` | Makes or edits an image through the Codex CLI's image tool. |
| `is-this-a-meme` | Typed only: `/is-this-a-meme <thing>` explains it, then lands it with a meme. The `dungeon-master` style memes on its own, and nothing else does. |

- **The `dungeon-master` output style**: relaxed, focused and exact. The answer first, the next action last, a register per topic, and memes when an idea needs to land. Pick it with `/output-style vicky-skills:dungeon-master`.
- **A guard hook** asks you before an agent edits approved examples: a file named `...ApprovedExamples` or holding a test marked `approved-spec`. It needs `jq`.
- **An after-push hook** reminds the agent, after a `git push`, to reread the pull request body and settle its work items. It only adds a note and never blocks. It needs `jq`.
- **Optional guard hooks**, each off until you turn it on under `/plugin`. They need `jq`, and every guard but the two thread and `tea` checks needs `git`.
  - **One pull request per effort** (`guard_pr`) refuses a session's second open pull request, unless it names a ticket filed before the session began. That exception reads ticket dates from a `plane` command, the repo's `bin/plane` or one on your `PATH`, and without one a second pull request is always refused. It also refuses stacks you didn't ask for and AI credit in pull request text. `guard_pr_ignore_heads` lists branch prefixes it skips. To let one refused command through, create the file `pr-guard-allow` in your Claude Code config folder from your own terminal. The command spends it.
  - **Whole threads** (`guard_issue_threads`) refuses a read of an issue or pull request that leaves out its comments.
  - **`tea` stdin** (`guard_tea_stdin`) refuses a `tea` call without `</dev/null`, which can hang until it times out. It needs `gawk`.
  - **No local paths** (`guard_local_paths`) refuses a commit that adds a home folder, a Nix store path or your username. It reads the staged changes, and also the unstaged and untracked ones when the same command runs `git add` or `commit -a`. `local_path_exempt_repos` lists repositories it skips.
  - **No pushing behind main** (`guard_push_behind`) refuses a push from a branch that main has moved past.

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
