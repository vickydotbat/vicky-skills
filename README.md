# vicky-skills

Claude Code skills for steering coding agents in any repository. You plan with star charts, approve the examples a build must pass before any code gets written, and get reviews on three axes. Agents are good at finding what you forgot, and if every find becomes a ticket, each finished task leaves you more tickets than it started with. So these skills fold finds into the work you're already doing, and a ticket gets filed only when the work truly has to wait.

```
/plugin marketplace add vickydotbat/vicky-skills
/plugin install vicky-skills@vicky-skills
```

Then type `/first-contact` once per repository. For a broken thing, type `/power-word-fix <what's broken>`. When you don't know where a session leads, type `/lay-course`.

No skill here shares a name with one of Matt Pocock's, so both plugins load without clashing. They describe two different workflows, so use one at a time.

This marketplace also serves a second plugin, [language-tutor](plugins/language-tutor/README.md). It tutors you in any language you name, with spaced review, quizzes and rubric grading. It shares nothing with vicky-skills, so install either one alone.

```
/plugin install language-tutor@vicky-skills
```

## Skills

Each skill starts on its own when its trigger fits, except the ones marked "When you type it". Skills end with a `Charter:` line naming the lines of `skills/CHARTER.md` they serve, and a test fails when one doesn't.

### Typed commands

| Skill | When it's used | What it does |
| --- | --- | --- |
| **`first-contact`** | When you type it | Sets a repository up once: where its tickets, glossary and decision records live, its testing standards (a `TESTING_STANDARDS.md` it writes, or a page the repo already keeps), and a pull request template unless the repo has one. It slims the agent file to rules and pointers, moving build steps to `CONTRIBUTING.md` and design notes to `ARCHITECTURE.md`. |
| **`power-word-fix`** | When you type it | `/power-word-fix <what's broken>` sorts the problem, runs the skills that fit and ends on proof. |
| **`soapbox`** | When you type it | Argues for or against each option of a choice in plain words, with pros, cons and its pick, so you can check its opinion before it goes on. |
| **`lay-course`** | When you type it | Starts a session you can't yet name. A council works out what you want, it files a star chart of tickets (or one star when the work fits in a session), then stops or warps. Before a chart is filed, it asks how the effort could fail and records a guard, an accepted risk or a ticket for each answer. |
| **`familiar`** | When you type it | Makes the session your familiar. It watches your other live sessions, keeps each snag in a debt note on your machine, tips you at the end of a stretch, and fixes or files each note at handoff. `Familiar: off` in a repo's tracker doc turns it off there. `familiar_kind` picks its voice (the owl by default, or the imp, quasit, raven, parrot, pseudodragon, cat or spider). `familiar_plugin_repo` names the checkout where fixes to this plugin get built. |
| **`conn`** | When you type it | Writes the state into tickets and pull requests, then posts a thin handoff: the goal, the links and what the session was in the middle of. After you clear, type `/sup`. |
| **`captains-log`** | When you type it | Runs a retrospective on a session and finds what would make the next one better, and what went well enough to keep. With the skill ledger on, it lists skills unused for 60 days with a pick for each: keep, merge or delete. |

### Planning

| Skill | When it's used | What it does |
| --- | --- | --- |
| **`mission-brief`** | When you ask to chart a plan, turn a plan into tickets, or convert tickets from another tool | Writes down what the conversation settled as a spec, cuts it into slices with Given / When / Then examples, and files a star chart with one star per slice after you approve the examples on a page. It asks no new questions. Tickets from another tool get re-sliced, never copied. One lone ticket goes to `groundhog-day`. |
| **`groundhog-day`** | When you ask to file, report or write up one bug, task or issue | Files one ticket you can take in at a glance. A bug gets a two-line summary, a screenshot as it looks now, steps to reproduce that it tried itself, more cases and related issues. Anything else gets a summary, a Done when line and related issues. It checks for a ticket on the same thing first, and adds to that one instead. |
| **`examples`** | Before a ticket is built, when a decision becomes a build, or when acceptance criteria are prose | Turns a ticket, rule or decision into Given / When / Then examples, opens them in your browser, and writes the ones you approve as failing tests. |
| **`council-of-elrond`** | When you type it | A table of eight designers (a skeptic, a dwarf with an axe, an elf, a ranger, a rules keeper, an enthusiast and two troublemakers) argues your idea with you. Each round ends on open points with a pick, and the council ends by picking the road: a star chart, one star, or a warp. |
| **`away-team`** | When a decision waits on a fact from docs, an API, source code or a spec | Answers the question from primary sources in a background agent and posts the findings on its ticket. |
| **`ui-design`** | Before a screen gets drawn or built, when `drawing-board` starts, or when a page hides what an option gives | Checks what a screen says: each option shows what it grants or costs before you pick, options sit side by side in one table, and contrast and target size meet the WCAG basics. |
| **`drawing-board`** | Before a window or screen layout gets built or resized, or when you say "sketch it" | Draws the window at true scale as a draw.io sketch in your browser. You move and resize boxes, and it reads your changes back as numbers and flags a broken size rule. |
| **`decision-record`** | When a broad rule gets decided or reversed, and before a decision record is edited | Writes architecture decision records (Status, Context, Decision, Consequences, Guard) so they stay true after a change of mind. A reversal is a new record plus one line on the old one. |
| **`post-mortem`** | When a fix failed before another found the cause, after an outage or lost data, or when you say "post-mortem" | Writes the incident down in the past tense: impact, timeline, detection, causes, earlier incidents with the same cause, lessons and follow-ups. A cause that keeps coming back ends up as one decision record, not one per symptom. |
| **`plot-twist`** | When you say "actually" or "instead", or reverse an earlier decision | Carries the change into every ticket, pull request and doc that still says the old thing. |

### Building

| Skill | When it's used | What it does |
| --- | --- | --- |
| **`do`** | When you ask for a change or hand over a ticket or star chart | Builds behaviour-first: you approve examples, each becomes a red test, the code turns them green, and mutation proves the tests catch bugs. A case no example covers comes back to you as a new example. Small work needs no chart or ticket. |
| **`warp`** | When you type it | Clears a star chart in one run, whole or just the stars you name. It opens the route in your browser for you to trim and answer, then builds every star through green CI in one pull request. Edge cases land in that pull request, never in follow-up tickets. A star that waits on someone else stays open and the landing report names it. |
| **`never-lupus`** | When something is broken, failing or slow | Finds the cause of a hard bug or slowdown with a loop that goes red on it. |
| **`sentinels`** | When `do` or a deathmatch asks for a mutation pass, or a mutation run dies | Mutation-tests changed code under a memory cap, with the repo's tool or by hand. |
| **`spark-joy`** | When you type it | Folds one shallow module in the busiest code into its caller, holds the behaviour with the tests at its seam, and opens a draft pull request. |
| **`by-eye`** | When a build needs to see a page it changed, when `do` turns an example you see on a page green, or when you ask it to "look at it" | Looks at a page in a windowless browser in light, dark, a narrow screen and keyboard-only, and leaves the screenshots in its scratch folder. It opens a windowed browser only when you must sign in. |
| **`over-to-you`** | When a change needs a real client, a look, real hardware or an outside account to prove | Hands the checks only a person can do to you as a checklist page, stocked with the props each check needs. You mark each item done, done with changes, failed or not tested. Every note goes on the ticket and nothing gets fixed until you type `/conn`. |
| **`stacked-branches`** | When a follow-up is big enough for its own pull request, when you ask for a stack, or when a stacked branch is checked out | Builds and merges a stack of dependent pull requests with `gh stack` or `git-spice`. Small changes stay on the effort's one pull request. |
| **`machine-spirit`** | Before changing CI, and when a CI run is red, slow or stuck | Writes and debugs CI. It names a failure's cause before it edits, so a retry or a raised timeout never stands in for a fix. |
| **`nwn-model-tooling`** | When working on Neverwinter Nights models, HAK files or headless Blender scripts | Points to Blender with Neverblender, `cleanmodels` and the neverwinter.nim tools, and how to call each. Plugin settings name your Blender commands and the folder of unpacked stock resources. |
| **`codex-image-gen`** | When you type it | Makes or edits an image through the Codex CLI's image tool. |
| **`video-captions`** | When a task links a video or asks what one says | Reads a video through its captions. When YouTube asks for a sign-in, it retries once with the browser named in `video_cookies_browser`, or tells you how to set one. |

### Review and shipping

| Skill | When it's used | What it does |
| --- | --- | --- |
| **`deathmatch`** | When `make-it-so` gets to its ready step, when an outside report or review arrives, or when you want a branch broken | Sends opponents at a branch: intent, holds, cause, simplicity, standards and claims, plus runaway and security when the diff calls for them. It keeps only the findings a run or a head-to-head contest proves, and fixes them on your own branch. |
| **`assimilate`** | When you type it | Judges a pull request on four questions: do the changes hold through CI on today's main, is the principle met, is it the cause or a symptom, and is there a better way. It posts the verdict, and claims the pull request in the Borg voice when it can make it better. |
| **`ship-it`** | When a pull request opens, a push changes it, or you ask for a description | Writes the pull request body in the repository's own template, or its own when there is none, and rewrites it when a push changes what the pull request does. It keeps the Status where the template puts it. |
| **`make-it-so`** | When you type it | Finishes a draft pull request: current with main, a QA checklist, every touched ticket settled, a true body, marked ready, then CI watched to green. |
| **`security`** | When a private security report arrives, when you ask for a CVE, an advisory or its publishing, and when you ask for a security check or review | Turns a proven report into a draft advisory only maintainers see, requests the CVE and publishes only when your own message says so, and runs four checks (baseline, secrets, CI, dependencies), each naming the tool run behind every finding. |
| **`history-monks`** | When you ask for a rebase on main, and before pushing a branch main has moved past | Rebases onto a main that moved. What landed owns the form, and the branch keeps its behaviour. |
| **`engrave`** | When you say "codify", "lesson", "for the future" or "from now on", when a snag cost a retry, and for each snag ticket settling finds | Turns one snag into a rule that stops it next time: one skill line for a first snag, then a harder fix (removing the wrong way, a check, a hook) each time it comes back. It proves the check fails on the real snag and ends with a `📓 Engraved:` line. |

### Writing

| Skill | When it's used | What it does |
| --- | --- | --- |
| **`human-voice`** | When writing prose a person reads, and when text sounds like AI | Writes anything a person reads in a register picked by its audience: showcase for the public, plain for everything else. A lint script catches the habits it can. A draft over about 400 words also goes to a panel of readers who list the questions it leaves. `reader_panel` picks `one agent` playing every seat (the default) or `agent per seat`. Each draft also gets a proofread from a second model, as [Proofreading](#proofreading) says. |
| **`red-pen`** | When writing meets an audience (players, customers, the public), or examples need your approval | Opens drafts in your browser and writes back what you leave. Specs, tickets, pull request bodies and internal docs skip it. |
| **`fireside-chat`** | When you type it | Interviews you for a post or article in your name, as the Bard, an old teller of tales at the fire who stays in character until the interview ends. It asks what only you know: the war story, the why, the credit. It gives a pick on choices like the angle or the picture, and none on the story, and it keeps your answers in your own words for the draft. |
| **`interactive-page`** | When a skill hands you a draft file or a checklist, or has a question with options for you | Shows the file as a page with text to edit, boxes to tick, comment boxes and options to click, and writes your answers back. With no browser, the file opens in your editor. |
| **`robot-voice`** | When creating or editing a skill, agent file or prompt, or when an agent misreads one | Writes skills, agent files and prompts for maximum agentic ergonomics. |
| **`loose-lips`** | Before any commit, push or post, and when writing docs a stranger could read | Checks anything leaving the machine for an attack map and rewrites it by role. |
| **`case-file`** | When you type it | Builds a case file in `.case-files/<name>/`, as research, a demonstration or a pitch, with a contents list and coloured labels, as a PDF to read first, with HTML and Markdown beside it. One zip per case holds them, the source and every file, and a rebuild replaces the old zip. Claims, events and quotes carry their dates on a timeline. Every claim carries its evidence: stock, test client only, estimate, failed or not tested. A check refuses the page if it names this machine. |

### Housekeeping

| Skill | When it's used | What it does |
| --- | --- | --- |
| **`gamma-shift`** | When you type it | Works through the tickets waiting on you. It builds up to three whose wait is over onto one draft pull request, lists the rest with what they wait on, and asks your open decisions as one round. |
| **`sup`** | When you type it | Catches you up in one screen: done, changed, lessons engraved, waiting on you, next. |
| **`cerebro`** | When you ask whether, how or why an agent or skill does something, after `captains-log` and `deathmatch`, when a decision is recorded, and at the end of `make-it-so` and `sup` | Answers questions about your agent setup, forecasts what you'll ask next and proposes the changes before you have to ask. |
| **`standing-orders`** | When you say "todo", "add to todo" or "for later", or work would otherwise be parked | Jots one short line in the repo's `.todo` (and adds `.todo` to `.gitignore` if needed). The line points at its star or ticket and goes when that closes. |
| **`summit`** | When you type it | Gives the breakdown behind the summit line: the tickets opened and closed since your last session and over 30 days, and the grade. A if you closed more than 10% above what you opened, C if more than 10% below, B in between. The count itself runs on its own at session start and shows in the viewscreen band, for any repo whose tracker doc has a `Summit count:` line. An Obsidian tracker needs the `obsidian_vault` setting. |

The `dungeon-master` output style is relaxed, focused and exact: the answer first, the next action last, and memes when an idea needs to land. Pick it with `/output-style vicky-skills:dungeon-master`.

## Hooks

A **(recommended)** hook only refuses, asks or warns. An **(experimental)** hook starts work by itself: it runs a skill or an agent in the background, writes to your repo, or tidies your branches. Read what one does before you turn it on.

Turn a hook on or off under `/plugin`, in the plugin's settings. The last column names the setting and its default. Most hooks need `jq`, and the git guards need `git`.

Many guards have a per-repo opt-out line, named in their rows.

### Experimental

| Hook | What it does | Setting |
| --- | --- | --- |
| **Auto-tidy** (experimental) | Runs at session start and after an agent merges a pull request with `gh` or `tea`. It deletes merged branches and their worktrees, and your own merged branches on the remote. It fast-forwards clean checkouts of main. A clone on a merged branch goes back to main, and its later commits move to a fresh branch. Unpushed work, uncommitted changes, open pull requests and locked worktrees stay. A worktree some session is working in stays too. Detached worktrees that main already holds go, and so do leftover folders under `.claude/worktrees`. On your GitHub or Gitea fork, added as a second remote, a branch whose pull request merged goes with its workflow runs, and the rest are counted. For forks you have no clone of, run `plugins/vicky-skills/scripts/manual/fork-sweep.sh` by hand. Once a branch's pull request merged or closed, it removes the `over-to-you` test kits made for it, except any you edited. You see one line about it, and the agent sees nothing. | On (`auto_tidy`) |
| **Summit** (experimental) | Runs at session start. It counts the tickets opened and closed since your last session and over the last 30 days, with the command on the `Summit count:` line of the repo's `docs/agents/issue-tracker.md`, and the viewscreen band shows the line. The agent sees nothing. A count that fails or takes over six seconds shows nothing. | On, for a repo with a `Summit count:` line |
| **Springboard** (experimental) | Keeps a marked block in a repo's `.todo` with at most five things only you can do, each with its link, and rebuilds it at session start and after a push, merge or page. A session opens on the first item. Your own lines stay. It touches only a repo whose `.gitignore` ignores `.todo`, and needs `gh`. | On (`standing_orders`) |
| **Lesson hint** (experimental) | When your message teaches a lesson ("codify that", "for the future"), tells the agent to run `engrave` before it replies. `plugins/vicky-skills/scripts/lesson-hint.sh` has the phrase list. | Off (`lesson_hint`) |
| **Keep awake** (experimental) | Keeps the computer from sleeping while any Claude Code session or subagent is working, background subagents included, and lets it sleep once every turn and subagent has ended. An agent with no tool call finishing for 30 minutes drops out, because Claude Code reports nothing when you press Esc. One tool call longer than that can let the computer sleep. Needs `systemd-inhibit` and `flock`. | Off (`keep_awake`) |

### Pull requests and git

| Hook | What it does | Setting |
| --- | --- | --- |
| **One pull request per effort** (recommended) | Keeps each session's work on one pull request, so CI runs once. A second one goes through only stacked on it with the `stacked` label, when the one below changes at least `guard_pr_stack_min_lines` lines (300) or the new body says why it's separate. A stack holds at most `guard_pr_stack_limit` (3). Quoted forge commands, such as a `sed` pattern, don't count (needs `gawk`). It also refuses a pull request, issue or comment that credits an AI, and a body with a `Skipped:` line naming review. It also refuses text that goes stale, such as a present-tense count or "currently", unless `Stale text: off` is in `docs/agents/domain.md`. In a repo `first-contact` set up, it refuses a body without each section the repository's pull request template asks for (or `ship-it`'s Status, Summary, Proof and Risk when it has none) or filled with `--fill`, unless `PR template: off` is in `docs/agents/issue-tracker.md`. A GitHub pull request to a repository you don't administer keeps that repository's own template. | On (`guard_pr`) |
| **Drafts until you ask** (recommended) | Refuses a pull request opened ready: `gh pr create` needs `--draft`, and `tea pr create` needs `--draft` or a `WIP:` title. Refuses marking one ready until `make-it-so` has started in the session. A raw `gh api` or `tea api` call, a forge MCP tool and a script file go unread. `PR drafts: off` in `docs/agents/issue-tracker.md` opts a repo out. | On (`guard_draft`) |
| **Ready-mark resume** (recommended) | When you mark a pull request ready yourself with a `!` command, reminds the agent that `make-it-so` isn't over: it watches CI to green, fixes red and settles the tickets. | On (`ready_resume_hint`) |
| **No pushing behind main** (recommended) | Refuses a push from a branch that main has moved past, and marking such a pull request ready. | On (`guard_push_behind`) |
| **Shellcheck before a push** (recommended) | Refuses a push when shellcheck finds a problem in a shell file the branch adds or changes, with the repo's own `.shellcheckrc`, so CI's shellcheck step doesn't go red on it. Without shellcheck installed the push runs. `Shellcheck: off` in `AGENTS.md` or a `docs/agents/` file switches it off. | On (`guard_shellcheck`) |
| **Rebasing onto main the careful way** (recommended) | Stops a rebase onto a main that has moved on until `history-monks` has started (once per session), so the branch follows what landed instead of just replaying over it. | On (`guard_rebase`) |
| **No restack onto a stale main** (recommended) | Refuses a git-spice command that rebases onto trunk while your local main differs from origin's. The fix is `gs repo sync` or `git fetch origin main:main`. `plugins/vicky-skills/scripts/restack-origin-guard.sh` lists the commands. | On (`guard_restack_origin`) |
| **Git branches, pushes and commits** (recommended) | Refuses a branch made on top of an unmerged branch, a push to main or master (and `--all` or `--mirror`), a commit message that credits an AI or goes stale (`Stale text: off` turns that part off), and a commit that sets its own author or committer. A branch from `origin/main` and a stack from `gh stack` or git-spice pass. A trunk repo (`Trunk: on` in `AGENTS.md`, `CLAUDE.md` or `docs/agents/`, or named in `git_guard_trunk_repos`) takes the push to main and refuses the new branch. | On (`guard_git`) |
| **No commits on a merged branch** (recommended) | Refuses a commit or push on a branch whose remote branch is gone, and gives the command for a fresh branch from main. At session start, and on the agent's commands in a checkout at most once every ten minutes, it tells the agent once when that checkout's branch has merged, and names the branches of your open pull requests there. | On (`guard_merged_branch`) |
| **Worktrees in one place** (recommended) | Refuses `git worktree add` anywhere but the repo's `.claude/worktrees/` folder, and keeps it out of `git status`. After a `git merge`, it removes the merged branch's worktree and branch. A `Drop worktree: <script path>` line in `docs/agents/testing.md` names a script to run for the removal instead. | Off (`guard_worktree_place`) |
| **Approved tests land first** (recommended) | Refuses a commit that adds a new approved-examples test with other changes, so the tests land red on their own. `plugins/vicky-skills/scripts/red-first-check.sh <base>` proves it on a branch, and this repo's CI runs it. | Off (`guard_red_first`) |
| **Only you make a repository public** (recommended) | Refuses making a repository public unless your last message says "public". It can't be taken back. | On (`guard_publish`) |
| **Only you request a CVE or publish an advisory** (recommended) | Refuses a CVE request unless your last message says "CVE", and publishing an advisory unless it says "publish". Before the fix ships, publishing takes a second "publish". Neither can be taken back. | On (`guard_publish`) |
| **Advisory deadlines** (recommended) | At session start, names each draft advisory due within a week whose fix hasn't shipped, and each one past its deadline. It publishes nothing. | Always on |
| **No local paths** (recommended) | Refuses a commit that adds a home folder, a Nix store path or your username. `local_path_exempt_repos` lists repos it skips, and a line marked `local-path-ok` passes. | On (`guard_local_paths`) |
| **No leaks in posts** (recommended) | Refuses a `gh` or `tea` pull request or issue post whose body names a path into this machine, holds terminal codes from a pasted view, or opens with another item's heading. A body it can't read, from `$(...)` or stdin, is refused with a steer to `--body-file`. Nothing in the body lets it through. | On (`guard_post_body`) |
| **Foreign post** (recommended) | When a `gh` command posts to a pull request or issue in a repository you don't administer, tells the agent to show you the text on a `red-pen` page first. It never refuses. | On (`foreign_post_hint`) |

### Tickets and CI

| Hook | What it does | Setting |
| --- | --- | --- |
| **Tickets only through a filing skill** (recommended) | Refuses `plane file`, `tea issues create` and `gh issue create` until the session has started `groundhog-day` for one ticket, `mission-brief` for a chart, or `away-team` for a ticket titled "Research: <question>". It always refuses a ticket titled "Familiar debt", since those notes stay on your machine. | On (`guard_ticket_filing`) |
| **Read a ticket whole** (recommended) | Refuses a ticket read cut short by `head`, `tail`, `sed -n`, `grep`, `cut` or `awk`, and points to `read-item.sh <id>`. A whole read is `read-item.sh`, `plane show`, or the command in the "Read, whole" row of `docs/agents/issue-tracker.md`. | On (`guard_whole_read`) |
| **Read before asking** (recommended) | Sends the agent back once when it ends a turn with a `🚪 Waiting on you:` offering coded options (O1, O2) and never read a ticket this session. A council or an earlier answer may have settled it. | On (`guard_read_before_asking`) |
| **Approved test lock** (recommended) | Refuses an edit, write or delete that changes the Given, When or Then lines of an approved test on the default branch, until the branch holds its ticked change record from examples' CHANGING.md. A shell command that changes one anyway gets the default branch's copy put back after it runs. | On (`guard_approved_test_lock`) |
| **Repeat-call steer** (recommended) | When the agent runs the same shell command 3 times in a row with the same output, tells it once to change approach or ask. A status poll that moves, or still shows a run pending, gets nothing. | On (`guard_repeat_call`) |
| **Done check** (recommended) | Before a turn or a subagent that changed files ends, runs the repo's `Check:` line from `docs/agents/testing.md` and sends the agent back with the last 40 lines when it fails. It gives up after 3 blocks in a row or 300 seconds. `Check: none` switches it off for a repo. | On (`guard_done_check`) |
| **Plane blocks need a hard reason** (recommended) | Refuses `plane block` unless the command ends with `# hard: <reason>`. Plane can't remove a blocked-by link, so a softer order goes in a `Waits on:` line. | Off (`guard_plane_block`) |
| **`tea` stdin** (recommended) | Refuses a `tea` call without `</dev/null`, which can hang. Needs `gawk`. | On (`guard_tea_stdin`) |
| **Check the gate first** (recommended) | Refuses a `🚪 Waiting on you:` message naming a pull request already merged or closed. A lookup that fails or takes over three seconds lets it through. | Off (`guard_gate_state`) |
| **sup finds the handoff** (recommended) | When `sup` starts, runs its handoff finder and gives the agent the result and every place it looked. | On (`sup_handoff_hint`) |
| **CI patch hint** (recommended) | When an edit to a CI workflow adds a retry, a sleep, `continue-on-error`, a skipped step or test, or a raised timeout, reminds the agent that `machine-spirit` wants the cause fixed. It never refuses. `Patch-tell hint: off` in `docs/agents/domain.md` turns it off. | On (`patch_tell_hint`) |
| **Workflow lint** (recommended) | Runs actionlint (and shellcheck on `run:` scripts when installed) on every CI workflow the agent writes, and hands back the findings. Runner labels are judged only when the repo lists its own in `.github/actionlint.yaml`. Needs `actionlint`. | On (`guard_workflow_lint`) |

### Agent behaviour

| Hook | What it does | Setting |
| --- | --- | --- |
| **Step hints** (recommended) | When `do`, `warp`, `examples`, `deathmatch`, `sentinels`, `over-to-you`, `make-it-so`, `council-of-elrond`, `gamma-shift`, `away-team` or `lay-course` starts, adds one line naming what its steps need. | Off (`step_guard`) |
| **Cerebro ask guard** (recommended) | When a `cerebro` proposal asks before a change only because it needs a new pull request, sends the reply back to build it. A revert undoes a pull request. | On (`guard_cerebro_ask`) |
| **Promise guard** (recommended) | When the agent owns up to a mistake and ends on a promise ("from now on I'll..."), sends it back to run `engrave` so the mistake becomes a check, hook or skill line. A promise lives only in one chat. | On (`guard_promise`) |
| **User-test guard** (recommended) | When the agent asks you to run a test in chat ("test it like this", "let me know if it works"), or ends on a 🚪 line that tells you to open, load or look at something, sends it back to run each check itself and open the `over-to-you` checklist page. That page opens only when every item has a receipt of the agent's own run. | On (`guard_user_test`) |
| **Decision-record hint** (recommended) | Reminds an agent writing a decision record that it holds a broad architecture rule, and a reason for one class, item or value goes in a comment at its code. | On (`adr_scope_hint`) |
| **A refused key is checked before it is blamed** (recommended) | After an ssh `Permission denied (publickey)`, tells the agent to compare your keys with the forge's and read the forge's status page before it asks you to add a key. | On (`guard_publickey_hint`) |
| **Fetch place** (recommended) | When a command downloads or unpacks into `/tmp`, reminds the agent to keep data outside git in one lasting place every checkout shares, and to look there before fetching again. It never refuses. | On (`fetch_place_hint`) |
| **No `pkill -f`** (recommended) | Refuses `pkill -f`, which also kills the shell running it. It steers to `kill <pid>` or `pkill -x`. | Always on |
| **Outside text writes nothing** (recommended) | Once deathmatch marks that a session read an outside pull request, bug report or review, refuses that session's pushes, new tickets and forge posts. Outside text can be written to steer the agent reading it, so that run only reports, and a person or a later run acts. You lift the mark yourself by typing the `! bash …/release-outside.sh` line the refusal prints; the guard refuses a command that names it. A glob or a variable that reaches the mark still slips past. | On (`guard_outside_text`) |
| **Reviewer briefs name real files** (recommended) | Refuses a reviewer or deathmatch opponent brief that names a file outside any checkout that doesn't exist, since the reviewer would then work without those rules and report clean. | Always on |
| **Opponents fight in batches** (recommended) | Refuses a deathmatch opponent launch while as many opponents as `batch.sh` allows are still fighting, and any launch beside Holds, which fights alone. An agent launched from a script hands back a receipt at once, so only the opponent's final notice frees its place. | Always on |
| **No merge while an opponent still fights** (recommended) | Refuses `gh pr ready`, `gh pr merge` and a Gitea merge while a deathmatch opponent from this session hasn't finished. An opponent can hand back an early report while its own runs go on, and only its last notice says it finished. | Always on |
| **Todo reminder** (recommended) | Lists a repo's `.todo` lines at session start. `Todo file: off` in `docs/agents/domain.md` silences it. | Always on |
| **Stale copy** (recommended) | Tells the agent once a session when it runs an older copy than the one installed. Type `/reload-plugins` to pick up the new one. | Always on |
| **Familiar voice** (recommended) | When you type `/familiar`, that turn gets your kind's voice, once, and the ask to keep it until the session ends. | Kind (`familiar_kind`), the owl by default |
| **Skill ledger** (recommended) | Adds a line to `skill-ledger.tsv` each time a skill starts: the time in UTC and the skill's name. The file stays in the plugin's data folder on your machine, and `captains-log` reads it. To clear it, delete the file. | Off (`skill_ledger`) |

### Display and alerts

| Hook | What it does | Setting |
| --- | --- | --- |
| **Gate notify** (recommended) | Raises a desktop notification when a message opens with `🚪 Waiting on you:` and on Claude Code's own alerts, except the idle one. Uses `notify-send`, or `osascript` on macOS. | Off (`gate_notify`) |
| **Viewscreen band** (recommended) | Sits above the prompt and says what the agent is doing and for how long, with a line naming the worktree, for every step and background agent. It's a Claude Code mod, so it needs function hooks turned on. | Always on |
| **Preview pane** (recommended) | `/preview <path>` shows a picture, or one frame of a video, in a pane beside the chat with an Open button. Terminals that can't draw images (kitty, Ghostty and iTerm2 can) show the file's name. JPEGs and video frames need ffmpeg. Part of the same mod as the band. | Always on |

## Install

The plugin needs Claude Code 2.1.271 or later. The two commands at the top install it. To offer it to everyone who works in a repository, run this once from that repository and commit the `.claude/settings.json` it writes:

```bash
claude plugin marketplace add vickydotbat/vicky-skills --scope project
```

Turn on auto-update under `/plugin`, then **Marketplaces**. The plugin has no version number, so every commit to `main` is an update.

## Proofreading

`human-voice` sends each draft to a second model for a proofread, then weighs its notes. The second model reports spelling, grammar, punctuation and unclear sentences. It leaves your voice and structure alone.

By default the proofread goes to Gemini 4 Hydrogen, which Google's free tier serves. Get a key from Google AI Studio and export it as `GEMINI_API_KEY` where Claude Code starts. Prompts on the free tier may be used to train Google's models, so keep private drafts off it.

Change it in the plugin's settings under `/plugin`:

- `proofread_model`: the model id. `session` keeps the proofread on the model you run Claude Code on.
- `proofread_endpoint`: any OpenAI-compatible API, such as OpenRouter or a local Ollama.
- `proofread_key_env`: the variable that holds that endpoint's key, or `none` for a server that needs no key.

A custom endpoint needs all three set, so your Gemini key never goes to another provider. With no key, no `curl` or `jq`, or a failed call, your session's model proofreads instead. The reply names the model that did the proofread, and the reason for any fallback.

## Approved examples

An example says what the game or app does, in its own words, with no code in it:

> Given a creature charmed by another, when its charmer hits it, then the charm ends.

The agent drafts examples, but only the ones you approve become tests, and each test must fail before the code exists. The `examples` skill has the rules for a good one.

The hook sees only edits made through Claude Code's edit tools. In each repository, back it with a merge gate: a code-owner rule naming you for files ending `ApprovedExamples`, or a CI check that refuses a change to one without your approval.

## The charter

`skills/CHARTER.md` says what the workflow is for in eight lines: you get what you meant, done is proven, facts come from their source, and so on. The `familiar` ties each snag it logs to the line the snag broke. A snag that breaks no line means the charter lacks one, so the familiar drafts it for you.

## Development

```bash
claude plugin validate .
tests/run-all.sh
```

Run both before every push. CI runs every test once a pull request is marked ready, and refuses a draft.

The skills' eval cases live in `plugins/vicky-skills/evals/`, and you run them by hand with the scripts in `tests/evals/`. Each run starts a real Claude session on your own credential, so CI never runs them, and each script refuses to start until you set `EVAL_SPEND=yes` and name the model under test in `EVAL_MODEL`. A case that passes writes that model and the date to a `passed` file in its folder. After a model upgrade, `law-lint.sh stale <model>` lists the laws whose proof passed on an older model, or never recorded a pass. A run is capped at $3, and one mission-brief run cost $0.22. `tests/eval-coverage.sh plugins/vicky-skills` names each skill with no case yet.

## Thanks

- Matt Pocock's [skills](https://github.com/mattpocock/skills): the base ideas, including `spark-joy`'s deep modules (from his improve-codebase-architecture) and `mission-brief`, folded from his to-spec and to-tickets into one step.
- Dex Horthy's [show-me](https://github.com/humanlayer/skills): `ship-it`'s pictures.
- The [No AI Slop Manifesto](https://www.slopmanifesto.com/), and ThePrimeagen's [video on it](https://www.youtube.com/watch?v=i1IbHVstmH4): the charter's reader-cost line, `ship-it`'s before and after screenshots, and `groundhog-day`'s bug ticket layout.
- [ponytail](https://github.com/DietrichGebert/ponytail): `do`'s smallest-change rules.
- Basecamp's [Shape Up](https://basecamp.com/shapeup): a star chart's black holes are its rabbit holes.
- The School of Knowledge's "The Rumsfeld matrix explained": a star chart's four boxes of knowns.
- OpenSSF's [OSV schema](https://github.com/ossf/osv-schema) (Apache-2.0): the `security` skill's OSV files, checked in the tests against a copy of its 1.9.2 schema.
- Tzafrir Rehan's [whats-agent-doing](https://github.com/tzafrir/whats-agent-doing): the viewscreen band, ported under its MIT License, which its files keep.
- Austin Marchese's videos [The ONLY 4 Things You Need To Prompt Like An Anthropic Engineer](https://www.youtube.com/watch?v=_NzakzRXzLI) and [Nate Herk: The Most Valuable AI Skill to Learn In 2027](https://www.youtube.com/watch?v=42Y6z9KKRKc): the reader panel, the planning pages in your browser, `captains-log`'s high points, the ticket-drift agent, and the never-a-V1 hook's tip (never let the AI hand you a V1).
- Lauren Tan's [pstack](https://github.com/cursor/plugins/tree/main/pstack): `human-voice`'s moves come from its `unslop` skill, and `engrave`'s ladder and replay of the real snag from its `correct`.
- Jimmy on Software's [7 Mistakes That Cause Fragile Code](https://www.youtube.com/watch?v=wbW2dqjNC5w) and double-trouble.dev's [Negative Space Programming](https://double-trouble.dev/post/negativ-space-programming/): the design moves in the review principles.
- Google's [Postmortem Culture](https://sre.google/sre-book/postmortem-culture/) chapter and Atlassian's incident handbook, for the post-mortem sections and the recurrence search: `post-mortem`.
- Gary Klein's [project premortem](https://hbr.org/2007/09/performing-a-project-premortem): the Foreseen lines a star chart gets before it is filed.
- The [architecture decision record guide](https://github.com/architecture-decision-record/architecture-decision-record), with Michael Nygard's sections: `decision-record`, whose Guard uses fitness functions.
- Martin Fowler's [Continuous Integration](https://martinfowler.com/articles/continuousIntegration.html), the CI and testing chapters of [Software Engineering at Google](https://abseil.io/resources/swe-book), and DORA's [capability guides](https://dora.dev/capabilities/): `machine-spirit`'s CI doctrine.
- Daniel Terhorst-North and Matt Wynne's example-guided development, the name for what behaviour-driven development, acceptance test-driven development and specification by example share. Dave Farley's [The Industry Is Catching Up](https://www.youtube.com/watch?v=EkH_uoybj8k) is the best short case for it. The main addition here is that you approve the examples before the agent writes any code.
- The Shadows Over Westgate team's coding and testing standards: STANDARDS.md's rules on boundary values, cheap and flaky tests, root causes, events over polling, schema migrations and what a session records.
- Caitlin Sadowski and colleagues' [Lessons from Building Static Analysis Tools at Google](https://cacm.acm.org/magazines/2018/4/226371-lessons-from-building-static-analysis-tools-at-google/pdf), with the ESLint, Ruff, ShellCheck, golangci-lint and BannedApiAnalyzers docs: the review principles' lint rule.
- Marco Emrich's [EXACT Coding](https://github.com/marcoemrich/EXACT-Coding), shown in Emily Bache's [interview on Modern Software Engineering](https://www.youtube.com/watch?v=a6HYpocKwXU): `examples`' check for entries no test would miss, its split for a star with more than six rules, and `do`'s predicted runs.
