---
name: cerebro
description: Read the need behind a question about the agent's own setup (its skills, agent files, output style, hooks, settings, workflow), answer it, then propose the changes to that setup the need implies, and stop for the user's pick. Use when the user asks whether, how or why an agent or skill does something ("does X check...", "is this automated", "do we have a skill for..."), when they report an agent behaviour they saw, and when the same kind of follow-up keeps arriving after your reports.
---

# Cerebro

> _Searching... one need found. Every gap it leaves is a proposal._

A question about the agent's setup rarely stands alone. The user asks "does `sup` check current state?" because an agent quoted something stale at them. The **need** is fresh state everywhere, and `sup` is one place it shows. Answer the question, then find what else in the setup falls short of the same need, so the follow-up arrives as a proposal instead of a correction.

## Steps

1. **Answer the question** from the record: read the skill, file or setting it asks about this session and quote the line. Done when the answer rests on a line you read.
2. **Read the need.** Ask why the user is asking now. Look at the reason their message gives, what just happened in the session, and the follow-ups they sent after earlier reports. Write the need in one line, as a behaviour they want from every agent. Done when the need is one line, or the question is plainly only curiosity: then stop after step 1.
3. **Find the gaps.** List the places in the setup that still fall short of the need: skills, agent files (`AGENTS.md`, `CLAUDE.md`), the output style, hooks and settings. Read each one before you call it short. Keep only gaps of the same need, inside the setup the question touched. A gap in another area or another need goes nowhere. Done when you hold three gaps at most, each with its file and the change.
4. **Propose and stop.** After the answer, give each gap one line, then your pick:

   ```markdown
   **Cerebro**
   - C1: <the change> in `<file>`, because <how it serves the need>.
   - C2: ...
   I'd take C1. Want it?
   ```

   Edit nothing the user hasn't picked. Done when the reply ends on the proposals and the one-line ask.
5. **Remember the need**, only when the session has auto memory: a memory directory shows in your context. Save the need and the user's answer as one feedback memory, so the next session proposes it unasked. With auto memory off, keep nothing: no notes file and no stand-in for memory. Done when the memory is saved, or auto memory is off.
