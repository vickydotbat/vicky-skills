---
name: power-word-fix
description: Fix anything the user names — a bug, a red check, wrong text, a leak, a stale decision — by sorting it and running the skills that fit, ending on proof.
argument-hint: "What's broken?"
disable-model-invocation: true
---

# Power word: fix

> _You speak the word. The thing is fixed, and you can prove it._

The user names something broken. Sort it, run the skills its kind calls for, and stop only on **proof**: a loop that was red is green, or the human's live check passes.

## Steps

1. **Restate it** in one sentence: what is broken, and what "fixed" looks like. Done when the user could answer it with a yes. Ask only when two readings lead to different fixes.
2. **Sort it** into one kind from the table. A problem of two kinds is two fixes, done in the table's order. Done when each part has a kind.
3. **Run the skills** for its kind, in order. Done when each skill's own last step is done.
4. **Prove it.** Rerun the loop that showed the problem and see it pass. For what only a person can see, hand it over with `over-to-you`. Done when the proof is in your reply: the command and its result, or the human's verdict.
5. **Close the loop.** Commit on the effort's branch, and run `loose-ends` when a ticket or pull request is involved. Done when nothing about the fix lives only in the chat.

## Kinds

| Kind | Signs | Skills, in order |
| --- | --- | --- |
| **Leak** | a secret, host, path or account power in text that left or is about to leave | `loose-lips` |
| **Red check** | CI, a hook, a linter or a test failing in a pipeline | `machine-spirit`, then the kind its cause turns out to be |
| **Bug** | wrong behaviour, a crash, a slowdown, a flaky test | `never-lupus`, then `do` |
| **Review finding** | a reviewer's hard or judgement finding | `do` for code, `human-voice` for prose (`red-pen` only for audience-facing text), then `review` on the axis that found it |
| **Stale decision** | a ticket, doc or agent file that says the old thing | `plot-twist` |
| **Wrong text** | a typo, a tone, a doc that says something false | `human-voice` for what people read, through `red-pen` when it meets an audience; `robot-voice` for what agents read |
| **Broken skill or agent file** | an agent keeps skipping, misreading or overdoing an instruction | `robot-voice`, "Debugging an instruction the agent ignores" |
| **Mess** | stale branches, worktrees or scratch files | `marie-kondo` |
| **Unknown** | none of the above fits | `interrogation` until a kind fits |

A leak goes first, whatever else is broken: anyone can copy it while it stands.
