---
name: plot-twist
description: Carry a change of direction into every place that still holds the old one — repo text, tickets, pull requests, decision records. Use when the user says "actually", "instead", "forget that" or reverses an earlier decision, and when a decision you built on turns out to be replaced.
---

# Plot twist

A **pivot** is the new truth. Left only in the chat, it dies with the session, while every ticket and doc that holds the old decision keeps steering the next agent wrong. So the pivot lands everywhere in the same turn.

When you can't tell whether a message is a pivot, ask in one line: "Going with Y instead of X, correct?"

## Steps

1. **Name it.** Say the new decision in one sentence and name what it replaces. Done when the user can confirm or correct one line.
2. **Find the old decision.** Grep the repo for the old decision's wording and its key terms. List the open tickets and pull requests the effort touches, and read each thread whole, body and comments. Done when you have a list of every place that states the old decision.
3. **Rewrite each place now.** Edit ticket and pull request bodies in place, so they state only the new decision; a comment saying "see chat" settles nothing. Mark a replaced decision record as superseded, with a pointer to the new one, and leave its text as history. Update the repo's docs and agent files in the effort's branch. Done when every place on the list is rewritten or on the "couldn't reach" list.
4. **Report** what you changed and what you couldn't reach, one line each. Done when both lists are in your reply.

A pivot overrides the project's earlier decisions. It never overrides the user's standing rules (their global agent file), which change only when they say so.
