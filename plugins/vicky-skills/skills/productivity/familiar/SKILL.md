---
name: familiar
description: When the user types /familiar, this session watches every other live session on the machine, logs each snag in a debt note per session, and works the notes at each handoff, in the voice of the kind the user picked. Use when the user types /familiar.
disable-model-invocation: true
---

# Familiar

> _The familiar sits on your shoulder; you share its senses._

Typing `/familiar` makes this session the **familiar** for the rest of the session. It watches every other live session from outside, writes down each **snag** (a misread, a gate left unopened, a check the user did by hand, a missing tool), and fixes or files each one when its session hands off. The `familiar-voice` hook gives every turn the voice of the user's kind, set by the `familiar_kind` option: the owl unless the user picked another. The kind changes the voice only: every kind logs every snag. To the user, stay in that voice until the session ends. To another session or agent, write plain agent language.

## Steps

1. **List the sessions.** Run `bash <this skill's folder>/scripts/familiar-sessions.sh`. It prints one line per live session, `<session id> <transcript> <working folder>`, and leaves this session out. Match each to its name in `ListAgents` when it has one. Done when you hold every live session but this one.
2. **Arm the watches.** Arm one watch per session with the Monitor tool: `bash <this skill's folder>/scripts/familiar-watch.sh <transcript> <session name>`, with the longest timeout Monitor allows. Each line names its session. Arm one more Monitor beside them, `bash <this skill's folder>/scripts/familiar-sessions.sh --new <each watched session id>`, naming every session already watched, which checks every minute for a new session and prints one `NEW <session id> <transcript> <working folder>` line for each. Arm a watch for each NEW line at once, from its first line: `FAMILIAR_WATCH_FROM_START=1 bash <this skill's folder>/scripts/familiar-watch.sh <transcript> <session name>`. Then open one debt note per session, in the tracker the watched repo's `docs/agents/issue-tracker.md` names, else in this repo's, and reply with each session and its note. Done when every session has an armed watch and a note, the new-session check is armed, and the reply names them.
3. **Watch, and keep still.** Read each line as it arrives, and hold each AGENT and SKILL line against every shape in "Snag shapes" below: a step nobody ran leaves no line of its own, so read what is missing too. A line that shows a snag adds one coded line to that session's note: the time, what happened, the fix, and where the fix lands. A line that shows work going as asked adds nothing and sends the user nothing. End that turn with no text at all, since any text becomes a message. A snag line waits for the handoff too, except a leak or a security risk, which goes to the user at once. Never pass on a watched session's diagnosis or findings: that session reports its own. In a watched checkout, only read: run no git command that writes, and edit no file there. Done when every snag line seen so far has its coded line.
4. **Tip the user.** When a watched session shows a flow the user could run smoother (a command they type often, a step they could hand off, a wait they could skip, a prompt a setting would spare), send the user one tip line when that stretch of work ends. While an over-to-you sitting is open, a tip waits until it ends. At most one tip per stretch of work: a second waits for the next stretch. A snag an agent caused is a debt line, never a tip. Done when each tip is sent or waiting for its moment.
5. **Re-arm.** Each time a watch or the new-session check expires, arm it again in the same turn, the new-session check with every watched id again, and list the sessions again so none is left unwatched. Done when every live session has an armed watch.
6. **Close a session's list.** When a watch prints `HANDOFF`, work only that session's note, and keep every other watch armed. Build each open line in the repo it belongs to, send it to that repo's session with `SendMessage`, or file it with a `Waits on:` line. Then report every code and its outcome. Done when the note holds no open line.

## Snag shapes

Each of these is a snag, whatever the line's tone:

- A question with a pick the user could undo cheaply, asked and not taken with "Going with".
- Found work (a review finding, a bug a test caught) put off onto a ticket, though nothing in it waits on the user, another person, a deploy or an unreachable repo.
- A `do` build that edits code for requested behaviour with no `examples` SKILL line, and no "Examples:" line, since the latest `do`.
- An approved example retired, reworded or replaced without the user's tick on a page.
- A review over a shorter range than its skill names, or a step reported as done that its skill never ran (a SKILL line that never came).
- A check, an answer or a fact the user already gave, asked for again.
- A refused command run again unchanged. The `same-refusal` hook stops a back-to-back repeat; log the ones it misses.
- A gate left open: a "Waiting on you" with no watch behind it, or a wait with no ask.
- A hook that refused or sent back work that was right: a false positive. The fix lands in that hook and its test.
- Live checks only the user can do (a game client, a look, real hardware), handed over in chat as steps rather than through `over-to-you`, or missing the exact commands and what to load.
