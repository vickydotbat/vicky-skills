---
name: plot-twist
description: Carry a change of direction into every place that still holds the old one: repo text, tickets, pull requests, decision records. Use when the user says "actually", "instead" or "forget that", when a decision you built on is replaced, when a test overturns a recorded rule, and when a ticket records a decision (an answered anomaly or away team) that an earlier plan or doc contradicts.
---

# Plot twist

> _The twist is canon now. Rewrite every page that says otherwise._

A **pivot** is the new truth. Left only in the chat, it dies with the session, while every ticket and doc that holds the old decision keeps steering the next agent wrong. So the pivot lands everywhere in the same turn.

When you can't tell whether a message is a pivot, ask in one line: "Going with Y instead of X, correct?"

## Steps

1. **Name it.** Say the new decision in one sentence and name what it replaces. A change the user didn't name, such as dropping a line or an option, goes in that sentence as a question, never into the pivot. Done when the user can confirm or correct one line.
2. **Find the old decision.** Search every place that can state it, never a list of files you picked:
   - the whole repo: `git grep -n -i -E '<old wording>|<key term>'`, decision records and agent files included;
   - every open ticket in the tracker, by title and body, whatever effort it belongs to: an open ticket that plans the old decision reads as live work;
   - the open pull requests the effort touches, and the wiki or docs site the repo mirrors to.

   Read each hit's thread whole, body and comments. Done when every search has run and each hit is on the list, or the search is on the "couldn't reach" list.
3. **Rewrite each place now.** Edit ticket and pull request bodies in place, so they state only the new decision; a comment saying "see chat" settles nothing. Mark a replaced decision record as superseded, with a pointer to the new one, and leave its text as history. Update the repo's docs and agent files in the effort's branch. Write text a person reads with `human-voice`, and agent files with `robot-voice`. Done when every place on the list is rewritten or on the "couldn't reach" list.
4. **Report** what you changed and what you couldn't reach, one line each. Done when both lists are in your reply.

A pivot overrides the project's earlier decisions. It never overrides the user's standing rules (their global agent file), which change only when they say so.

Charter: C3 ([CHARTER.md](../../CHARTER.md)).
