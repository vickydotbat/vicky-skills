---
name: conn
description: Write a thin handoff so a fresh session can pick up this work after a clear. Use when the context is near its limit, the user ends a session mid-effort, or an over-to-you read-back ends one.
argument-hint: "What will the next session do?"
disable-model-invocation: true
---

# Conn

> _You have the conn. The log lives in the tickets; the handoff only points at it._

A **handoff** is a short comment a fresh agent reads first, after the user clears the context. The tickets and pull request bodies hold where the work stands, so the handoff holds only the goal, the links and what this session was in the middle of. It is a lead, never a fact: the next session checks each line before it builds on it.

## Steps

1. **Write the state where it lives first.** Rewrite the Status section of each open pull request the work touched, as `ship-it` says, and move each ticket's state and `Waits on:` line, as `loose-ends` says. Put each small item for later in `.todo` with `standing-orders`. Done when a fresh session could read where the work stands from those records alone.
2. **Name the goal** in one sentence, shaped by the user's argument when they gave one. Done when the sentence names one outcome.
3. **Point, don't copy.** Link each ticket, pull request, decision record, commit and file the work rests on. Restate nothing those already hold: no done, next or waits-on lines. Done when every item the work rests on has a link.
4. **Name the mid-work**: what this session was in the middle of that no record holds yet, such as uncommitted edits, a half-run check or a theory being tested. Beside each line, write the command that shows it, or `unchecked`. Done when each line has its command or `unchecked`.
5. **Name the skills** the next session should call. Done when each skill is named with its reason in a few words.
6. **Post it.** Open it with a `**Handoff**` line, so `sup` finds it. It names no path outside the repo: commit scratch work it needs, or name it by what it holds. Run `loose-lips` on it before you post. Post it as a comment on the effort's open pull request or ticket, with the "Comment" action in `docs/agents/issue-tracker.md`. With no tracker, write it as a note where the user's own agent instructions keep that project's notes. Done when the comment's link is in your reply, or the note's path is in your reply when there is no tracker, with the line the user types after the clear to pick it up: `/sup`.

After the post, the session is handoff-only until the user clears. A new fact or ask from the user goes into the handoff comment and the records step 1 names, and nothing else: no test, no run, no code, no debug logging. Edit the handoff comment in place, then end the turn with its link. `idle-stop-guard` lets every stop through once conn has run, so nothing pushes for a next step.

Done when a stranger could start from the handoff and the links alone.

Charter: C5 ([CHARTER.md](../../CHARTER.md)).
