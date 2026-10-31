# vicky-skills

Claude Code skills for steering coding agents in any repository: star charts for planning, test-first builds, and reviews on three axes. They're built on ideas from [Matt Pocock's skills](https://github.com/mattpocock/skills), `ship-it`'s pictures come from Dex Horthy's [show-me](https://github.com/humanlayer/skills), `do`'s smallest-change rules from [ponytail](https://github.com/DietrichGebert/ponytail), `spark-joy`'s deep modules from Matt's improve-codebase-architecture, and `mission-brief` from Matt's to-spec and to-tickets, folded into one step. A star chart's black holes are the rabbit holes from Basecamp's [Shape Up](https://basecamp.com/shapeup). The viewscreen band is Tzafrir Rehan's [whats-agent-doing](https://github.com/tzafrir/whats-agent-doing), ported under its MIT License, which its files keep. The reader panel, the planning pages in your browser, `captains-log`'s high points and the ticket-drift agent come from two of Austin Marchese's videos, [The ONLY 4 Things You Need To Prompt Like An Anthropic Engineer](https://www.youtube.com/watch?v=_NzakzRXzLI) and [Nate Herk: The Most Valuable AI Skill to Learn In 2027](https://www.youtube.com/watch?v=42Y6z9KKRKc). The main addition is approved examples: you approve the examples a build must pass before the agent writes any code.

No skill here shares a name with one of Matt's, so both plugins load without clashing. They describe two different workflows, though, so use one at a time.

| Skill | When it's used | What it does |
| --- | --- | --- |
| **`first-contact`** | When you type it | `/first-contact` sets a repository up for these skills, once: where its tickets, glossary and decision records are. |
| **`power-word-fix`** | When you type it | `/power-word-fix <what's broken>` sorts the problem, runs the skills that fit and ends on proof. |
| **`lay-course`** | When you type it | The lazy way in when you don't know where a session leads. You pick a council or an interrogation to work out what you want. It files a star chart of tickets, or a single ticket (a star) when the work fits in a session, and then stops or warps to it. Every star's spec is its approved examples. |
| **`mission-brief`** | When you type it | `/mission-brief` writes down what the conversation already settled as a spec, cuts it into slices with Given / When / Then examples, and opens the lot in your editor. Whatever you leave there is filed as a star chart, one star per slice. It asks you no new questions. An open one becomes an anomaly on the chart. |
| **`warp`** | When you say "warp" or "engage", or `lay-course` engages it | Clears a whole star chart in a single run: every star it can reach, or just the stars you name. It first files whatever those stars need that has no ticket yet. Then it opens the route in your browser: the charts, and a table with each ticket, its kind and what it needs from you. You trim it and answer its questions on that page, and it takes every answer up front and builds each star through to green CI in one pull request, without dropping out. What blocks it, it clears, works around or waits out. A star that waits on someone else stays open, and the landing report names it. |
| **`examples`** | Before a ticket is built, when a decision becomes a build, or when acceptance criteria are prose | Turns a ticket, rule or decision into Given / When / Then examples, opens them in your editor, and writes the ones you approve as failing tests. |
| **`do`** | When you ask for a change or hand over a ticket or star chart | Builds behaviour-first from a request typed in chat, a ticket or a whole star chart: you approve Given / When / Then examples in your editor, each becomes a red test, the code turns them green, and mutation proves the tests catch bugs. A case no example covers comes back to you as a new example. Small work needs no chart or ticket. |
| **`review`** | When you want a branch, pull request or work in progress reviewed | Reviews a branch on three axes at once: standards, spec and simplicity. Each axis is its own agent, and a diff under 40 lines gets one quick pass instead. They share one list of review principles: one point of entry, data read from its source, one copy of logic, and tests proved by mutation. |
| **`never-lupus`** | When something is broken, failing or slow | Finds the cause of a hard bug or a slowdown with a loop that goes red on it. |
| **`ship-it`** | When a pull request opens, a push changes it, or you ask for a description | Writes a pull request body, and rewrites it when a push changes what the pull request does. |
| **`machine-spirit`** | Before changing CI, and when a CI run is red, slow or stuck | Writes and debugs CI: workflows, path filters, runners, caches, required checks, and runs that are red, slow or stuck. |
| **`stacked-branches`** | Only once you ask for a stack, or when a stacked branch is checked out | Builds and merges a stack of dependent pull requests with `gh stack` or `git-spice`, once you ask for a stack. |
| **`human-voice`** | When writing prose a person reads, and when text sounds like AI | Writes anything a person reads, in a register picked by the audience: eccentric and enthusiastic for a public showcase, plain for everything else. A lint script finds the tells a script can catch, and every hit is rewritten before you see the draft. A draft over about 400 words also goes to a panel of readers from its audience, who list the questions it leaves them with. The agent answers what it can in the draft and shows you the rest. Its `reader_panel` setting picks `one agent` playing every seat, the default, or an `agent per seat`. |
| **`ui-design-101`** | When building or reviewing buttons, confirmations, deletes or per-row actions | Designs the actions in an interface for their hundredth use. |
| **`over-to-you`** | When a change needs a real client, a look, real hardware or an outside account to prove | Hands the checks only a person can do to you, as a short checklist in your editor with room for notes. It covers the whole branch, except what you've already passed on record. A long list comes in numbered sittings of seven, and nothing is dropped. |
| **`loose-lips`** | Before any commit, push or post, and when writing docs a stranger could read | Checks anything leaving the machine for an attack map and rewrites it by role. |
| **`robot-voice`** | When creating or editing a skill, agent file or prompt, or when an agent misreads one | Writes skills, agent files and prompts for maximum agentic ergonomics. |
| **`plot-twist`** | When you say "actually" or "instead", or reverse an earlier decision | Carries a change of direction into every ticket, pull request and doc that still says the old thing. |
| **`make-it-so`** | When you say "make it so" or "ship it", and when `do` ends | Finishes a draft pull request: current with main, a QA checklist where a command or one read decides each item, a true body, marked ready, then CI watched until it's green. |
| **`gamma-shift`** | When you say "gamma shift" or ask what's waiting on you, or at session start when its setting asks | Works through the tickets waiting on you. Each one whose wait is over gets built to a draft pull request for you to read, the rest are listed with what they still wait on, and your open decisions come back as one round of questions. Its `gamma_shift` setting picks what happens at session start: `off`, `remind` for a one-line count, or `engage` for a run in the background. |
| **`loose-ends`** | Before calling an effort done, after every push to an open pull request, and after a merge | Settles every ticket an effort touched and keeps the pull request body true. Before the effort is done, it runs `engrave` on each snag the effort hit. |
| **`marie-kondo`** | When an effort lands, on a first visit to a repo, or when you ask for a cleanup | Deletes merged branches and worktrees and keeps what sparks joy. |
| **`spark-joy`** | When you say "spark joy" or "deepen", or every few days when its setting asks | Folds one shallow module in the busiest code into its caller, with the tests at its seam holding the behaviour, and opens a draft pull request. Its `deepen_every_days` setting runs it in the background at session start every that many days, and `0`, the default, never does. |
| **`red-pen`** | When text needs your read before it is committed or published | Opens drafts in your editor and writes back what you leave. |
| **`cerebro`** | When you ask whether, how or why an agent or skill does something, after `captains-log` and `review`, when a decision is recorded, and at the end of `make-it-so` and `sup` | Looks forwards. It answers a question about your agent setup, reads the follow-ups you've sent, forecasts what you'll ask next, and proposes the changes before you have to ask. It asks itself the questions you'd ask about each proposal, and the answers go into the proposal. |
| **`council-of-elrond`** | When you ask for a council, pick it in `lay-course`, or bring a design question with no answer yet | Puts your idea in front of a table of designers. A skeptic, a dwarf with an axe, an elf who looks far ahead, a ranger who walks it through, a rules keeper, an enthusiast and two troublemakers with new ideas argue it with you, whether it's a game rule, a character build or a piece of code. The chair and the rules keeper speak every round, and the rest take turns, so you hear every voice at least every other round. Each round ends on open points, each with a pick, and the council ends by picking the road: a star chart, one star, or a warp right now. Once it starts, every reply comes from the seats, answers to your questions included. The agent starts one when you ask for it, pick it in `lay-course`, or bring a design question you haven't answered yet. |
| **`interrogation`** | When you say "grill me" or "interrogate me", or an anomaly needs your answers | Is the council's hard mode: it asks you questions only, the sharpest first, until nothing is left open, and writes your answers as examples. |
| **`true-names`** | When a term is fuzzy or disputed, or when editing the glossary or a decision record | Sharpens a project's terms in its glossary and records decisions as you make them, each one what, category, when and why in at most 55 words. |
| **`away-team`** | When a decision waits on a fact from docs, an API, source code or a spec | Answers a question from primary sources in a background agent and posts the findings on the ticket the question belongs to. |
| **`sup`** | When you ask "sup" or "where are we", return after a break, or a long stretch of work ends | Catches you up in one screen: done, changed, lessons engraved, waiting on you, next. |
| **`you-have-the-conn`** | When you type it | `/you-have-the-conn` writes a handoff so a fresh session can pick up where this one stopped. Every claim in it names the command that proved it. |
| **`captains-log`** | When you type it | `/captains-log` looks backwards: it runs a retrospective on a session and finds what would make the next one go better. It also finds what went exceptionally well and marks the line behind it kept, so a later cleanup leaves that line alone. With the skill ledger on, it lists the skills nobody has started in 60 days, each with a pick: keep, merge or delete. Its follow-up trends and high points go to `cerebro`. |
| **`engrave`** | When you say "codify", "lesson", "for the future" or "from now on", when you correct the agent, and for each snag `loose-ends` or `captains-log` finds | Turns one snag into a rule that stops it next time: a check or a hook where one fits, a skill line where neither does. It builds the rule this turn and ends with a `📓 Engraved:` line. The rule goes to the plugin's repo, your `CLAUDE.md` or the project repo, whichever owns it. |
| **`history-monks`** | When you ask for a rebase on main, and before pushing a branch main has moved past | Rebases a branch onto a main that moved: what landed owns the form, the branch keeps its behaviour, and the old patterns a merge hides get converted too. |
| **`sentinels`** | When `do`, `placebo` or a review asks for a mutation pass, or a mutation run dies | Mutation-tests changed code with the repo's tool, a tool pulled down for the run, or by hand, and keeps a run alive under a memory cap. |
| **`placebo`** | Whenever a test is written or reviewed; the audit runs only when you ask for it | Lists the kinds of test that look like proof and catch nothing, and the agent checks every test it writes or reviews against them. Ask it for an audit and it deletes, merges or rewrites them across a suite. |
| **`retcon`** | When you say "undo", "revert" or "put it back" | Undoes exactly what you name, and leaves every other change alone. |
| **`nwn-model-tooling`** | When working on Neverwinter Nights models, HAK files or headless Blender scripts | Points to the Blender with Neverblender, `cleanmodels` and the neverwinter.nim tools, and how to call each. Its plugin settings name your Blender commands and the folder of unpacked stock resources. |
| **`video-captions`** | When a task links a video or asks what one says | Reads a video through its captions. |
| **`codex-image-gen`** | When a task says "use codex" for an image, or a `codex exec` call looks stuck | Makes or edits an image through the Codex CLI's image tool. |
| **`is-this-a-meme`** | When you type it | `/is-this-a-meme <thing>` explains it, then lands it with a meme. The `dungeon-master` style memes on its own, and nothing else does. |

- **The `dungeon-master` output style**: relaxed, focused and exact. The answer first, the next action last, a register per topic, and memes when an idea needs to land. Pick it with `/output-style vicky-skills:dungeon-master`.
- **A guard hook** stops an agent from editing approved examples: a file named `...ApprovedExamples` or holding a test marked `approved-spec`. It also stops a shell command that writes one, such as `sed -i`, a redirect or a script. The refusal tells the agent to send the new wording to you in a `red-pen` draft. When you change it there and close the file, that one test file opens for edits, with no prompt. A command that only runs or reads one goes through, and so does writing a new one. It needs `jq`.
- **An after-push hook** reminds the agent, after a `git push`, to reread the pull request body and settle its work items. It only adds a note and never blocks. It needs `jq`.
- **Optional guard hooks**, each off until you turn it on under `/plugin`. They need `jq`, and every guard but the two thread and `tea` checks needs `git`.
  - **One pull request per effort** (`guard_pr`) refuses a session's second open pull request, unless it names a ticket filed before the session began. That exception reads ticket dates from a `plane` command, the repo's `bin/plane` or one on your `PATH`, and without one a second pull request is always refused. It also refuses stacks you didn't ask for and AI credit in pull request text. `guard_pr_ignore_heads` lists branch prefixes it skips. To let one refused command through, create the file `pr-guard-allow` in your Claude Code config folder from your own terminal. The command spends it. A pull request counts as the session's once the forge prints its address.
  - **Whole threads** (`guard_issue_threads`) refuses a read of an issue or pull request that leaves out its comments.
  - **Plane blocks need a hard reason** (`guard_plane_block`) refuses `plane block` unless the command ends with `# hard: <reason>`. Plane's API can add a blocked-by link but not remove one, so a softer order goes in a `Waits on:` line in the body.
  - **`tea` stdin** (`guard_tea_stdin`) refuses a `tea` call without `</dev/null`, which can hang until it times out. It needs `gawk`.
  - **No local paths** (`guard_local_paths`) refuses a commit that adds a home folder, a Nix store path or your username. It reads the staged changes, and also the unstaged and untracked ones when the same command runs `git add` or `commit -a`. `local_path_exempt_repos` lists repositories it skips. A line marked `local-path-ok` passes, for a test fixture that needs a path.
  - **No pushing behind main** (`guard_push_behind`) refuses a push from a branch that main has moved past.
  - **No commits on a merged branch** (`guard_merged_branch`) refuses a commit or push on a branch whose remote branch is gone. The refusal gives the command for a fresh branch from main. It also lists the commits to carry over, or says that nothing needs moving.
  - **No skipped do steps** (`step_guard`) refuses to mark a `do` build's pull request ready, with `gh pr ready` or by dropping `WIP:` from a Gitea title, when its review never ran and the body gives no `Skipped: review, because` reason. When `do` starts, it also reminds the agent that each step needs its proof.
  - **Short polls** (`guard_poll_pace`) refuses a wait that sleeps more than 30 seconds at a time, polls more than 60 times, or loops in the foreground. Agents wait with `scripts/watch.sh` instead, under Claude Code's Monitor tool.
  - **One session per checkout** (`guard_checkout`) refuses a branch switch in a checkout another session used in the last 12 hours, and tells a session once when its checkout moved to another branch under it. It keeps each session's last git command per checkout in the plugin's data folder until the session ends.
  - **Approved tests land first** (`guard_red_first`) refuses a commit that adds a new approved-examples test together with other changes, so the tests land red on their own. `plugins/vicky-skills/scripts/red-first-check.sh <base>` proves each approved test a branch adds failed at the commit that added it, and this repo's CI runs it.
  - **No commit with a stale mutation proof** (`guard_mutation_proof`) refuses a commit while the repo's mutation proof is out of date. A repo opts in with a `Mutation proof check:` line in `docs/agents/testing.md`, and the refusal names its `Mutation proof refresh:` command. This repo's proof is `tests/mutation-proof.tsv`.
  - **No code while a draft is open** (`guard_draft_lock`) refuses edits to the repo while `red-pen` has a draft open in your editor. Writes outside the repo still run.
- **A session-start hook** runs `gamma-shift` when its `gamma_shift` setting is `remind` or `engage`, and stays quiet when it's `off`, the default.
- **A gate-notify hook** (`gate_notify`, off by default) raises a desktop notification when an agent's message opens with `🚪 Waiting on you:`, and on Claude Code's own needs-your-input alerts. It uses `notify-send`, or `osascript` on macOS, and needs `jq`.
- **A spark-joy hook** (`deepen_every_days`, `0` by default) runs `spark-joy` in the background at the first session start in a repo after that many days. With `gamma_shift` at `engage`, the run goes last in gamma-shift's queue instead.
- **An auto-tidy hook** (`auto_tidy`, off by default) prunes origin's branches at session start, and asks the agent to run `marie-kondo` when a local branch's upstream is gone, as it is after a merge in the browser.
- **A lesson hint hook** (`lesson_hint`, off by default) adds one line of context when your message teaches a lesson, such as "codify that" or "for the future". The agent then runs `engrave` before it replies. `plugins/vicky-skills/scripts/lesson-hint.sh` has the full phrase list. It needs `jq`.
- **A ticket-drift hook** (`drift_every_days`, `0` by default) starts the `ticket-drift` agent in the background at the first session start in a repo after that many days. The agent reads each open ticket against its comments and the merged pull requests that name it. Where they contradict the body, it comments on the ticket and edits nothing. A repo turns it off with the line `Ticket drift: off` in its `docs/agents/issue-tracker.md`.
- **A skill ledger hook** (`skill_ledger`, off by default) adds a line to `skill-ledger.tsv` each time a skill starts, whether the agent starts it or you type it. Each line holds the time in UTC and the skill's name. The file sits in Claude Code's data folder for this plugin, and nothing leaves your machine. `captains-log` reads it to find skills nobody starts. To clear it, delete the file. Uninstalling the plugin deletes the folder. It needs `jq`.
- **The viewscreen band** sits above the prompt and says what the agent is doing right now, and for how long. Open it to see every step of the session, each marked done, failed, denied or interrupted, and a row for each background agent. It's a Claude Code mod, so it only shows where your Claude Code has function hooks turned on.
- **A todo reminder hook** lists the lines of a repo's `.todo` file at session start, for jobs too small to deserve a ticket. The agent deletes a line once it's done. With no `.todo` file it says nothing. `first-contact` adds `.todo` to `.gitignore`, and `Todo file: off` in `docs/agents/domain.md` silences it.

## Install

The plugin needs Claude Code 2.1.271 or later. In a Claude Code session:

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
tests/run-all.sh
```

Run both before every push. CI runs every test once a pull request is marked ready, and refuses a draft.
