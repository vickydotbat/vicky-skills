---
name: standing-orders
description: Jot a line in the repo's .todo so work carries over between sessions, without asking. Use whenever the user says "todo", "add to todo" or "for later", whenever you would report work as parked or left for a follow-up, and when a star or ticket a .todo line points at closes.
---

# Standing orders

> _Standing orders outlast the watch. Write them down; the next shift carries them out._

A **standing order** is one line in the repo's `.todo`, outside the springboard block, that keeps work moving between sessions. It is one sentence of at most 80 characters, and it points at the star, chart or ticket it moves when one exists: `Finish the inventory 2.0 star chart (GAME-12)`. The plugin's `springboard` hook tells you to shorten a longer line after you write it. A line the user wrote may run longer.

When the session-start context says standing orders are off, keep no `.todo` lines and report parked work in chat.

## Steps

1. **Jot it, unasked.** When the user says "todo", "add to todo" or "for later", or you would report something as parked or as a follow-up, append its line to `.todo` now. Ask first only when it is truly unclear whether the user wants the work at all. Done when the line is in `.todo`.
2. **Tell the user** in one line that holds the line itself and says it waits for them, in the voice the session's output style sets. Play it up a little: `Standing order logged: <the line>. Engage when ready.` Never write "parked:" in its place. Done when the reply holds that line.
3. **Grow it.** When the work outgrows one line, file it as a star or ticket, and rewrite the line to point at it. Done when the line names the star's or ticket's key.
4. **Strike it.** Delete a line once its work is done or what it points at closes. `loose-ends` and `gamma-shift` sweep for these. Done when no line points at closed work.

Work with real impact gets a ticket or a star from the start, and its line only points at it.
