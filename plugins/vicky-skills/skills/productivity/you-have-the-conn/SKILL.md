---
name: you-have-the-conn
description: Write a handoff so a fresh session can pick up this work. Use when the context is near its limit or the user ends a session mid-effort.
argument-hint: "What will the next session do?"
disable-model-invocation: true
---

# You have the conn

> _You have the conn. Trust the log only where it shows its proof._

A **handoff** is a short file a fresh agent reads first. It is a lead, never a fact: the next session checks each claim before it builds on it.

1. **Name the goal** in one sentence, shaped by the user's argument when they gave one. Done when the sentence names one outcome.
2. **Point, don't copy.** Link each ticket, pull request, decision record, commit and file the work rests on. Restate nothing those already hold. Done when every item the work rests on has a link.
3. **Prove each state claim.** Beside every claim about a branch, file, setting or ticket, write the command that proved it this session, or `unchecked`. Done when no claim stands bare.
4. **List what is open**: decisions the user still owes, and work started but not finished. Done when each open item has an owner, the user or the next session.
5. **Name the skills** the next session should call. Done when each skill is named with its reason in a few words.
6. **Save it** in the system's temp folder (`$TMPDIR`, else `/tmp`), never in the repo, and give the user its path. Leave out every secret and every personal detail. Done when the path is in your reply.

Done when a stranger could start from the file and the links alone.
