---
name: cerebro
description: Answer a question about the agent's own setup, or forecast the user's next asks, and propose the changes each implies before the user has to ask. Use when the user asks whether, how or why an agent or skill does something ("do we...", "does it...", "is this...", "why did..."), when they report an agent behaviour they saw, after `captains-log`, and at the end of a report that closes a stretch of work.
---

# Cerebro

> _Searching... one need found. Every gap it leaves is a proposal._

Cerebro looks forwards, and `captains-log` looks backwards. A question about the setup rarely stands alone: the user asks "does `sup` check current state?" because an agent quoted something stale at them. The **need** is fresh state everywhere, and `sup` is one place it shows. A report rarely ends the work either: what the user asks next is usually a need they've already shown. Cerebro finds both, so the next ask arrives as a proposal instead of a correction.

It runs one of two ways:

- **Question**: the user asked about the setup. Run steps 1, 2, 4, 5 and 6.
- **Forecast**: a report just closed a stretch of work, or a retrospective handed over its follow-up trends. Run steps 2 to 6, and skip the answer.

## Steps

1. **Answer the question** from the record: read the skill, file or setting it asks about this session and quote the line. Done when the answer rests on a line you read.
2. **Read the need.** Read the session's follow-ups as [FOLLOW-UPS.md](FOLLOW-UPS.md) says, and the reason the user's latest message gives. For a forecast, also read the open tickets and pull requests the work touched. Write the strongest need in one line, a trend first. Done when the need is one line, or nothing points past the work just reported: then end with step 1's answer, or with nothing in a forecast.
3. **Forecast the next asks.** Name at most three things the user is likely to ask next, each from the need: the same need on the next piece of work, a risk the report raised and left open, or a decision the last change makes due. Done when each forecast names the need it comes from.
4. **Find the gaps.** For each forecast and for the need, find where the setup or the work falls short: a skill, an agent file (`AGENTS.md`, `CLAUDE.md`), the output style, a hook, a setting, a ticket, or the code just shipped. Read each one before you call it short. Done when you hold three gaps at most, each with its file and the change.
5. **Propose and stop.** After the answer or the report, give each gap one line, then your pick:

   ```markdown
   🧠 **Cerebro**
   - C1: <the change> in `<file>`, because <the next ask it answers>.
   - C2: ...
   I'd take C1. Want it?
   ```

   Edit nothing the user hasn't picked. Done when the reply ends on the proposals and the one-line ask.
6. **Remember the need**, only when the session has auto memory: a memory directory shows in your context. Save the need and the user's answer as one feedback memory, so the next session proposes it unasked. With auto memory off, keep nothing: no notes file and no stand-in for memory. Done when the memory is saved, or auto memory is off.
