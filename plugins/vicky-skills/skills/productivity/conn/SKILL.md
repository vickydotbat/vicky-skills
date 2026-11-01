---
name: conn
description: Write a thin handoff so a fresh session can pick up this work after a clear. Use when the context is near its limit or the user ends a session mid-effort.
argument-hint: "What will the next session do?"
disable-model-invocation: true
---

# Conn

> _You have the conn. The log lives in the tickets; the handoff only points at it._

A **handoff** is a short file a fresh agent reads first, after the user clears the context. The tickets and pull request bodies hold where the work stands, so the handoff holds only the goal, the links and what this session was in the middle of. It is a lead, never a fact: the next session checks each line before it builds on it.

## Steps

1. **Write the state where it lives first.** Rewrite the Status section of each open pull request the work touched, as `ship-it` says, and move each ticket's state and `Waits on:` line, as `loose-ends` says. Put each small item for later in `.todo` with `standing-orders`. Done when a fresh session could read where the work stands from those records alone.
2. **Name the goal** in one sentence, shaped by the user's argument when they gave one. Done when the sentence names one outcome.
3. **Point, don't copy.** Link each ticket, pull request, decision record, commit and file the work rests on. Restate nothing those already hold: no done, next or waits-on lines. Done when every item the work rests on has a link.
4. **Name the mid-work**: what this session was in the middle of that no record holds yet, such as uncommitted edits, a half-run check or a theory being tested. Beside each line, write the command that shows it, or `unchecked`. Done when each line has its command or `unchecked`.
5. **Name the skills** the next session should call. Done when each skill is named with its reason in a few words.
6. **Save it** in the system's temp folder (`$TMPDIR`, else `/tmp`), never in the repo, and give the user its path. Leave out every secret and every personal detail. Done when the path is in your reply.

Done when a stranger could start from the file and the links alone.
