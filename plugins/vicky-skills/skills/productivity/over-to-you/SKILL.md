---
name: over-to-you
description: Hand the live checks only a person can do to the human, as a short checklist opened in their editor with room for notes, then read their verdicts back. Use when a change needs a real client, a look, a feel, real hardware or an outside account to prove, or the user asks to test something themselves.
---

# Over to you

> _Over to you in the field. Everything the agent can run, it already ran._

Everything the agent can run, it runs, and only the rest goes **over to you**.

## Steps

1. **Pick the human-only checks across the whole branch.** Source items from the whole branch, never from the latest work alone: every ticket the branch, its commits or its pull request body names, and every feature area in `git diff --stat <base>...HEAD`. Keep an item only when no command can prove it: what a person sees or feels in the real client, real hardware, an outside account, a timing a test can't hold. Run every other check yourself first. Leave out an item the user already passed only when the pass is on record: a verdict on the pull request's Proof section, a ticket comment, or an earlier over-to-you file the user closed with a pass. Done when every ticket and changed feature area has an item, a recorded sign-off, or a reason no person can check it, and each item left fails the question "could a command prove this?"
2. **Get the stage ready.** Build, start the servers, seed the data and check out the branch, so the human starts at item 1 with no setup. Done when the opening line can say where everything is.
3. **Write the checklist** in the system temp folder (`$TMPDIR`, else `/tmp`) as `over-to-you-<topic>.md`, in the form below, with `human-voice`. Use seven items or fewer per sitting. A longer list becomes numbered sittings, one file each (`over-to-you-<topic>-1.md`, `-2.md`), and none is dropped. Take items from the approved examples where they exist, one each. Address the human by name, or "Bob" when you don't know it. Done when the file exists in the form below.
4. **Open it** the way `red-pen` step 2 opens a draft file, and wait for the close. Done when the editor has exited or the user said done.
5. **Read it back.** Each item is ticked, unticked or annotated. Take an unticked item back into the loop (`never-lupus` to find the cause, `do` to fix it). Record the verdicts where the work lives: the pull request's Proof section, or a comment on the ticket. Done when every item has a verdict on record.

## Form

```markdown
# Over to you, <name>!

<one line: what to open, where, and on which branch or build>
<sitting <n> of <total>, when there is more than one>
signed off: <each item left out, with where its pass is recorded, or "nothing yet">

1. [ ] <verb first: what to do> → <what you should see>
   notes:

2. [ ] <...> → <...>
   notes:

## Back to you in the studio

verdict: pass | fail | partly
notes:
```

Each item is one line. A step that needs explaining is two items.
