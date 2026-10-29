---
name: over-to-you
description: Hand the live checks only a person can do to the human, as a short checklist opened in their editor with room for notes, then read their verdicts back. Use when a change needs a real client, a look, a feel, real hardware or an outside account to prove, or the user asks to test something themselves.
---

# Over to you

The anchor hands over to the field: everything the agent can run, it runs, and only the rest goes **over to you**. The checklist is short enough to finish in one sitting, and every line is one action and its expected result.

## Steps

1. **Pick the human-only checks.** Keep an item only when no command can prove it: what a person sees or feels in the real client, real hardware, an outside account, a timing a test can't hold. Run every other check yourself first. Done when each item left fails the question "could a command prove this?"
2. **Get the stage ready.** Build, start the servers, seed the data and check out the branch, so the human starts at item 1 with no setup. Done when the opening line can say where everything is.
3. **Write the checklist** in the system temp folder (`$TMPDIR`, else `/tmp`) as `over-to-you-<topic>.md`, in the form below. Use seven items or fewer, and split a longer list into two sittings. Take items from the approved examples where they exist, one each. Address the human by name, or "Bob" when you don't know it.
4. **Open it** with `$VISUAL` (else `$EDITOR`) and wait for the editor to close. Done when the editor has exited.
5. **Read it back.** Each item is ticked, unticked or annotated. Take an unticked item back into the loop (`never-lupus` to find the cause, `do` to fix it). Record the verdicts where the work lives: the pull request's Proof section, or a comment on the ticket. Done when every item has a verdict on record.

## Form

```markdown
# Over to you, <name>!

<one line: what to open, where, and on which branch or build>

1. [ ] <verb first: what to do> → <what you should see>
   notes:

2. [ ] <...> → <...>
   notes:

## Back to you in the studio

verdict: pass | fail | partly
notes:
```

Each item is one line. A step that needs explaining is two items.
