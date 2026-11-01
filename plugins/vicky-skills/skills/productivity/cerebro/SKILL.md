---
name: cerebro
description: Answer a question about the agent's own setup, or forecast the user's next asks, and propose the changes each implies before the user has to ask. Use when the user asks whether, how or why an agent or skill does something ("do we...", "does it...", "is this...", "why did..."), when they report an agent behaviour they saw, after `captains-log`, and at the end of a report that closes a stretch of work.
---

# Cerebro

> _Searching... one need found. Every gap it leaves is a proposal._

Cerebro looks forwards, and `captains-log` looks backwards. A question about the setup rarely stands alone: the user asks "does `sup` check current state?" because an agent quoted something stale at them. The **need** is fresh state everywhere, and `sup` is one place it shows. A report rarely ends the work either: what the user asks next is usually a need they've already shown. Cerebro finds both, so the next ask arrives as a proposal instead of a correction.

It runs one of two ways:

- **Question**: the user asked about the setup. Run steps 1, 2 and 4 to 7.
- **Forecast**: a report just closed a stretch of work, a review reported, a decision was recorded mid-effort, or a retrospective handed over its follow-up trends. Run steps 2 to 7, and skip the answer.

## Steps

1. **Answer the question** from the record: read the skill, file or setting it asks about this session and quote the line. Done when the answer rests on a line you read.
2. **Read the need.** Read the session's follow-ups as [FOLLOW-UPS.md](FOLLOW-UPS.md) says, and the reason the user's latest message gives. For a forecast, also read the open tickets and pull requests the work touched. For a forecast, also run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/summit.sh show` from the repo: a 30-day verdict of B or C is a trend, and its proposals aim at closing more, never at finding less. Write the strongest need in one line, a trend first. Done when the need is one line, or nothing points past the work just reported: then end with step 1's answer, or with nothing in a forecast.
3. **Forecast the next asks.** Name at most three things the user is likely to ask next, each from the need: the same need on the next piece of work, a risk the report raised and left open, or a decision the last change makes due. Done when each forecast names the need it comes from.
4. **Find the gaps.** For each forecast and for the need, find where the setup or the work falls short: a skill, an agent file (`AGENTS.md`, `CLAUDE.md`), the output style, a hook, a setting, a ticket, or the code just shipped. Read each one before you call it short. Done when you hold three gaps at most, each with its file and the change.
5. **Ask as the user.** Read each change as the user would, and list the questions the user would ask about it: what they will see, what it replaces, what it costs to undo. Answer each from the record, and fold the answer into that proposal or the ticket it files. A proposal that raises no question stands alone, with no empty question list. Done when every question has its answer in a proposal or a ticket.
6. **Take the picks.** The user wants each recommended change: assume the yes. Build every proposal you would pick in this turn, then report each one with its proof. Ask first only for a proposal a wrong guess would make expensive to undo, such as a deletion, a published post or a setting another person relies on:

   ```markdown
   🧠 **Cerebro**
   - C1: <the change> in `<file>`, because <the next ask it answers>. Done: <proof>.
   - C2: <the change> in `<file>`, because <...>. Waits on you: <why a wrong guess costs too much>. Want it?
   ```

   Under a proposal that raised questions in step 5, indent one line per question with its answer. Done when every picked proposal is built and reported, and the reply asks only about the ones a wrong guess would make expensive to undo.
7. **Remember the need**, only when the session has auto memory: a memory directory shows in your context. Save the need and the user's answer as one feedback memory, so the next session proposes it unasked. With auto memory off, keep nothing: no notes file and no stand-in for memory. Done when the memory is saved, or auto memory is off.
