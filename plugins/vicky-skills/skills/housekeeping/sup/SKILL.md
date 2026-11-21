---
name: sup
description: Catch the user up in one screen — what got done, what changed, what waits on them, what comes next. Use when the user asks "sup", "what's up", "where are we", "catch me up" or "status report", returns after a break, or a long stretch of work ends.
disable-model-invocation: true
---

# Sup

> _Sup? Read the record, not your memory._

A **catch-up** answers four questions, plus the lessons engraved, for someone who just walked in. They read it once and know what to do. It covers the time since the user's last message, or since the point they name.

## Steps

1. **Read the record, not your memory.** Check the branch, the commits, open pull requests and the tickets the work touched, now, because other sessions change them. Find the handoff with `bash ${CLAUDE_PLUGIN_ROOT}/skills/housekeeping/sup/scripts/find-handoff.sh [<ticket key>...]`: it reads the comments on this branch's open pull request, each ticket the branch or pull request names, the `.todo` Handoff line on every branch (a link, a `!<n>` pull request whose comments it reads, or a ticket key), the tickets `.todo` names when it has no Handoff line and the branch names none, and earlier session transcripts that name the branch or a key, and prints each `found:` hit, the places it searched and each place it could not read. Read each `not read:` place by hand, and with no tracker, look for the newest such note where the user's own agent instructions keep that project's notes. Name the handoff, and check each of its lines before you report one: a handoff is a lead, not a fact. The `sup-handoff-hint` hook runs it when `sup` starts and hands you its output. An earlier-session hit is a lead, like the handoff. A catch-up with no handoff quotes the script's `none found in:` and `not read:` lines. Done when the script's output is in this turn and each claim you will make has a fresh command behind it.
2. **Write the parts**, one line per item, with a short code on each so the user can answer by code:

   ```markdown
   **Done** — <what landed, with its proof: a merged PR, a passing check>
   **Changed** — <decisions made or reversed, and what they replaced>
   **Lessons** — <n> engraved: <snag>, <snag>
   **Waiting on you** — <questions and approvals, two options at most, recommendation first>
   **Next** — <the one next action>
   ```

   Read Lessons from the ledger engrave keeps for every repo: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/lesson-ledger.sh since <that point in UTC, as 2026-10-31T12:00:00Z>`, one line per lesson, each with its snag and its home. With no lesson, leave Lessons out, and leave out any other empty part. Done when the whole thing fits on one screen.
3. **Add parked work.** Fresh parking: offer a line only when its refs are still open now. `bash ${CLAUDE_PLUGIN_ROOT}/skills/housekeeping/sup/scripts/parked-state.sh` prints one verdict per `.todo` line, and the `sup-handoff-hint` hook hands you that output:
   - `open:`, `no ref:` or `unread:`: the line may be offered.
   - `done:`: every ref finished. Offer nothing, and strike the line with `standing-orders`. Quote each struck line in the catch-up.
   - `merged-ticket-open:`: its pull requests merged and its ticket is still open. Offer nothing from the line. Read its thread, then close the ticket unasked with the tracker's Close operation, strike the line with `standing-orders`, and quote both under Done. A merged effort closes its ticket: an open one after a merge is a `Closes` line the pull request left out. Two exceptions keep it open, each named under Done with the thread line that holds it, and ask nothing:
     - a star chart with open children;
     - a thread that records, after the merge, a done-when still unmet.

   When the user moved away from something unfinished, end with at most three lines: "Still want X?" Count only work they left, not work you found. Done when each parked item is asked once or dropped, no `done:` or `merged-ticket-open:` line was offered, and each `merged-ticket-open:` ticket is closed or names its exception.
   Proven by: tests/parked-state.test.sh
4. **Pick up a handoff.** When step 1 found a `**Handoff**` comment or note, run `do` on the work it names, after the catch-up is sent. When the `.todo` Handoff line names other work than the branch's own handoff, the `.todo` line is the newer pointer: resume it, and name the branch's work under Still want: the ticket or pull request it links is the source, so `do` step 0 asks nothing, and `do` resumes at the step that work's records show. Skip step 5 then: `do` ends in its own report. Done when `do` has started on the handed-off work, or no handoff was found.
5. **Look ahead.** Run `cerebro` as a forecast. Done when its proposals end the catch-up, or it found nothing to forecast.

Charter: C5 ([CHARTER.md](../../CHARTER.md)).
