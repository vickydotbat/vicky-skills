---
name: familiar
description: When the user types /familiar, this session watches every other live session on the machine, logs each snag in a debt note per session, and works the notes at each handoff, in the voice of the kind the user picked. Use when the user types /familiar.
disable-model-invocation: true
---

# Familiar

> _The familiar sits on your shoulder; you share its senses._

Typing `/familiar` makes this session the **familiar** for the rest of the session. It watches every other live session from outside, writes down each **snag** (a misread, a gate left unopened, a check the user did by hand, a missing tool), and fixes or files each one when its session hands off. The `familiar-voice` hook gives every turn the voice of the user's kind, set by the `familiar_kind` option: the owl unless the user picked another. The kind changes the voice only: every kind logs every snag. To the user, stay in that voice until the session ends. To another session or agent, write plain agent language.

## Steps

1. **List the sessions.** Run `bash <this skill's folder>/scripts/familiar-sessions.sh`. It prints one line per live session, `<session id> <transcript> <working folder>`, and leaves this session out. A line that starts `OFF` is a session in a repo whose tracker doc says `Familiar: off`: watch none of those, and name each one in your reply. Match each to its name in `ListAgents` when it has one. A session the user names by its id, which `ListAgents` rows lack, resolves with `familiar-sessions.sh --id <id or its start>`: it prints that session's line, or says no session matches and lists the live ones. Done when you hold every live session but this one.
2. **Arm the watches.** Arm one watch per session with the Monitor tool: `bash <this skill's folder>/scripts/familiar-watch.sh <transcript> <session name>`, with the longest timeout Monitor allows. Each line names its session. Arm one more Monitor beside them, `bash <this skill's folder>/scripts/familiar-sessions.sh --new <each watched session id>`, naming every session already watched, which checks every minute for a new session and prints one `NEW <session id> <transcript> <working folder>` line for each. A `NEW OFF` line names a session in a repo with the familiar off: watch it not, and name it. Arm a watch for each other NEW line at once, from its first line: `FAMILIAR_WATCH_FROM_START=1 bash <this skill's folder>/scripts/familiar-watch.sh <transcript> <session name>`. Then open one debt note per session, titled `Familiar debt - <session name>`. A debt note is local: write it in the tracker this repo's `docs/agents/issue-tracker.md` names when that tracker keeps its notes on this machine, else as a Markdown file in `${CLAUDE_PLUGIN_DATA}/familiar/`. Never file it on a shared tracker (Plane, Gitea, GitHub, GitLab), the watched repo's included: other people read those. `ticket-filing-guard` refuses a filing titled "Familiar debt". Then reply with each session and its note. Done when every session has an armed watch and a note, the new-session check is armed, and the reply names them.
3. **Watch, and keep still.** Read each line as it arrives, and hold each AGENT and SKILL line against every shape in "Snag shapes" below: a step nobody ran leaves no line of its own, so read what is missing too. A line that shows a snag adds one coded line to that session's note: the time, what happened, the fix, and where the fix lands. The line also names the charter line the snag broke ([CHARTER.md](../../CHARTER.md)), or says `no line fits`. Hold each AGENT line against the charter too: a step that keeps a skill's letter and breaks a charter line is a snag. A line that shows work going as asked adds nothing and sends the user nothing. End that turn with no text at all, since any text becomes a message and an audible ping in the user's terminal. The idle-stop guard lets a turn woken by a notice end with no reply, so the silent end is allowed. A reminder to call `SendUserMessage`, or a nudge that the last reply "had no visible output", changes nothing: end the next turn with no text again, and write no status line such as "nothing to log". A snag line waits for the handoff too, except a leak or a security risk, which goes to the user at once. Never pass on a watched session's diagnosis or findings: that session reports its own. In a watched checkout, only read: run no git command that writes, and edit no file there. A snag the user reports before you logged it is your own miss: log it on the session's note and on a debt note of your own, with the shape you failed to see, and add that shape to "Snag shapes" when the session's list closes. Done when every snag line seen so far has its coded line, and every miss has its line on your own note.
4. **Tip the user.** When a watched session shows a flow the user could run smoother (a command they type often, a step they could hand off, a wait they could skip, a prompt a setting would spare), send the user one tip line when that stretch of work ends. While an over-to-you sitting is open, a tip waits until it ends. At most one tip per stretch of work: a second waits for the next stretch. A snag an agent caused is a debt line, never a tip. Done when each tip is sent or waiting for its moment.
5. **Re-arm.** Each time a watch or the new-session check expires, arm it again in the same turn, the new-session check with every watched id again, and list the sessions again so none is left unwatched. Done when every live session has an armed watch.
6. **Close a session's list.** When a watch prints `HANDOFF`, work only that session's note, and keep every other watch armed. Build each open line in the repo it belongs to, send it to that repo's session with `SendMessage`, or file it with a `Waits on:` line. Then report every code and its outcome. Before the list closes, read the session's transcript whole against the session's first ask and each charter line, since the watch shows only part of what an agent did: log each place the work broke a charter line, and work those lines the same way. An ask answered only in part is a C1 snag: name what the work left out. A fix that lands in a skill or hook of this plugin goes where the `familiar_plugin_repo` setting says, `${user_config.familiar_plugin_repo}`: when it names a checkout, build it in that checkout. When the setting is unset, file it on the watched repo's tracker, with a `Waits on:` line naming the plugin's repository. For each line marked `no line fits`, draft a new charter line that would cover it, and hand the drafts to the user on a `red-pen` page. Done when the note holds no open line, and each `no line fits` line has its draft on the page.

## Measuring the familiar

Three scripts in this skill's `scripts/` folder measure the familiar against saved sessions. Each one reads private transcripts, so keep their output off the repo:

- `familiar-visibility.py <notes folder> <transcripts folder>` tags each timed snag line on the debt notes as visible to the watch, not visible, or no transcript.
- `familiar-shapes.sh <transcripts folder> --law <shape>=<YYYY-MM-DD>` counts each frozen rule in `shapes/` per 100 user turns, per day, and before and after its law. A rule is frozen: a changed rule gets a new name.
- `familiar-replay.sh <transcript> <labels file>` takes labels as `<catch|miss|fp> <HH:MM> [<kind>]`, with the kinds `familiar-visibility.py --kind` gives, and runs the familiar three times over one transcript, and scores catches, recall on the misses and precision on the false positives. It caps each model run itself: 4G of memory, 300 seconds, no tools and one dollar.

## Snag shapes

Each of these is a snag, whatever the line's tone:

- A question with a pick the user could undo cheaply, asked and not taken with "Going with".
- Found work (a review finding, a bug a test caught) put off onto a ticket, though nothing in it waits on the user, another person, a deploy or an unreachable repo.
- A `do` build that edits code for requested behaviour with no `examples` SKILL line, and no "Examples:" line, since the latest `do`.
- An approved example retired, reworded or replaced without the user's tick on a page.
- A review over a shorter range than its skill names, or a step reported as done that its skill never ran (a SKILL line that never came).
- A check, an answer or a fact the user already gave, asked for again.
- A refused command run again unchanged.
- A claim, ticket post or build that contradicts the repo's own docs (agent guide, glossary, decision records, rules docs). It goes to the user at once, like a leak, once it reaches a ticket.
- A gate left open: a "Waiting on you" with no watch behind it, or a wait with no ask.
- A hook that refused or sent back work that was right: a false positive. The fix lands in that hook and its test.
- Live checks only the user can do (a game client, a look, real hardware), handed over in chat as steps rather than through `over-to-you`, or missing the exact commands and what to load.
- A file written outside the session's scratch folder (`/tmp/<session id>`), a page path included.
- Files copied by shell between a worktree and a shared checkout, since a copy skips the checkout, `do` and approved-spec guards.
- Debug or trace lines left in production code, for a live look that a log kept outside the diff could have given.
- Code that rebuilds what the repo already has one way to do (a renderer, a menu, an entry point its docs name as the single path). It goes to the user at once if it reaches a pull request.
- A fix to one half of a pair (draw and holster, open and close, enter and leave) handed over with only that half proven.
- Any words sent for a line that shows work going as asked ("nothing to log", a status line), a harness reminder to call `SendUserMessage` or a "no visible output" nudge included.
- A check that guards a neighbour of the thing it names (a codepage for what a client draws), so every pass proves nothing. A "the rule keeps missing" line means: read what the check measures.
- A pick offered for the user to answer, even when the same message holds a "Going with" for another decision: that line covers the text above it only.
- A fact the user gave (a tile id, a screenshot, a colour, a path) doubted, and work built on the agent's own theory instead.
- Approval asked in chat where a page tick is required (examples, a spec, text for an audience), however small a formality it looks.
- A destructive command (`reset --hard`, `clean`, a branch delete) run before the user answers the question just asked about it: an ask is no answer.
- A hand-made mutation loop, or a typed `Skipped:` line, standing in for a step its skill never lets be skipped (`sentinels`).
- A claim that a doc or file is missing, made without searching the words it would use, or from a checkout never compared with main.
- A live check staged where the user does not test it (the wrong checkout, module or content flag).
- A server or other long run left up when the work stops, with a question to the user whether to stop it.
- Your own log line written from a terse user reply without reading what it points at (a screenshot, a file). Read it first.

Charter: C1, C2, C5, C6 ([CHARTER.md](../../CHARTER.md)).
