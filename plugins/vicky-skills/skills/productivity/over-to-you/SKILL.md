---
name: over-to-you
description: Hand the live checks only a person can do to the human, as a short checklist opened as a page in their browser with room for notes, then read their verdicts back. Use when a change needs a real client, a look, a feel, real hardware or an outside account to prove, or the user asks to test something themselves.
---

# Over to you

> _Over to you in the field. Everything the agent can run, it already ran._

Everything the agent can run, it runs, and only the rest goes **over to you**.

## Steps

Read the repo's `TESTING_STANDARDS.md` first: it wins over this skill's defaults. With no such file, the defaults stand.

1. **Pick the human-only checks across the whole branch.** Source items from the whole branch, never from the latest work alone: every ticket the branch, its commits or its pull request body names, and every feature area in `git diff --stat <base>...HEAD`. Keep an item only when no command can prove it: what a person sees or feels in the real client, real hardware, an outside account, a timing a test can't hold. Run every other check yourself first: an outcome a test could assert (a stack merges, a line is or isn't sent, an item lands in a cell) becomes that test, run green on the branch, and never an item. Run the repo's test for the whole branch too (its `TESTING_STANDARDS.md` names the command), so no test the branch added reaches a sitting unrun. Leave out an item the user already passed only when the pass is on record: a verdict on the pull request's Proof section, a ticket comment, or an earlier over-to-you file the user closed with a pass. Wording is no item: each player-facing or UI text the branch writes or changes goes in the effort's `red-pen` draft file instead. Done when every ticket and changed feature area has an item, a recorded sign-off, or a reason no person can check it, each item left fails the question "could a command prove this?", and the draft file holds every new text. The `step-hint` hook repeats this when the skill starts.
2. **Get the stage ready.** The user tests in the repo's main checkout, always, so put the branch there: commit and push it, remove its worktree (git checks a branch out in one place only), then switch the main checkout to the branch. When the main checkout holds uncommitted changes, stop and ask the user what to do with them. Build, start the servers and seed the data, so the human starts at item 1 with no setup. Stock every item: make the props, the state and the scripts each check needs (two stacks of arrows that differ in one local variable, a character at the right level), or give the item the one command that makes them, so the user never builds a prop by hand. Make them by the means the project's docs describe: a test module, a seed script, a test-only script folder, or the `Test props:` line in `TESTING_STANDARDS.md`. Build each kit as "Kits" below says. With no place named, use something disposable (a script, a scratch save, a throwaway record), remove it after the sitting, and ask the user where test props live from now on. Write the answer as the `Test props:` line in `TESTING_STANDARDS.md`. A prop goes in the test surface or a disposable, never in content that ships. Done when the main checkout is on the branch with no worktree left for it, the opening line can say where everything is, and every item's props exist or have their command.
3. **Write the checklist** in the system temp folder (`$TMPDIR`, else `/tmp`) as `over-to-you-<topic>.md`, in the form below, with `human-voice`. Use seven items or fewer per sitting. A longer list becomes numbered sittings, one file each (`over-to-you-<topic>-1.md`, `-2.md`), and none is dropped. Take items from the approved examples where they exist, one each. Address the human by name, or "Bob" when you don't know it. Done when the file exists in the form below and `python3 <this skill's folder>/scripts/lint-checklist.py <file>` prints nothing. Each `person:` line names one reason only a person can check the item: look, feel, real client, second client, extender, hardware, outside account or timing.
4. **Open it** the way `red-pen` step 2 opens a draft file, and wait for the close. When the effort's draft file holds sections, open it with `red-pen` first and write its text back, so the sitting checks the approved wording. Done when the user pressed Done, the editor has exited, or the user said done.
5. **Read it back.** Each item carries its mark and notes, and Extra tests and Other hold anything the user added. Act on each quick note as "Quick notes" below says, by its tag. Take an unticked item back into the loop (`never-lupus` to find the cause, `do` to fix it). Record the verdicts where the work lives: the pull request's Proof section, or a comment on the ticket. Then clean up as "Kits" says. Done when every item has a verdict on record and nothing the kits made is left.

## Kits

A kit is what one check needs to run: the things it acts on, their state, and the script that makes them.

- Build each check its own things, from scratch: a mark to pickpocket is a creature spawned for that check, friendly, in reach and carrying what the check takes, and never borrow one already in the world. <!-- kept 2026-10-31: a pickpocket mark built fresh for its check passed first time, "Perfect", after a borrowed one failed -->
- Reuse only what you already know works. A thing an earlier test may have changed (made hostile, left busy, moved) makes the check flaky for a person and for a machine alike, so build a new one.
- Finish each thing (its properties set, its locals written) before it reaches the place where it could combine, such as a stack that would merge in a pack.
- When the sitting closes, remove everything the kits made, and commit no kit file, unless TESTING_STANDARDS.md allows it and says where. When it does, commit it there and only there.

## Quick notes

Every section, Extra tests and Other end with a quick-notes block: one line per tag, each blank. The user fills the lines they need, and repeats a tag on a new line for a second note. On read-back, each tag says what to do:

| Tag | The user means | Do |
| --- | --- | --- |
| BUG | Something is broken or wrong. | Fix it now, and put it back on the next sitting's list. |
| QUIRK | It works, but something is odd. | Fix it now, or say in the report why not. |
| FRICTION | It works, but it feels bad to use. | Propose the fix, and build it when it is cheap. |
| UGLY | It looks wrong. | Fix it now, with the project's visual proof. |
| IDEA | A new feature, or a ticket for the map. | File it as a ticket on the right map; the report names it. |
| RULE | A lesson to codify. | Run `engrave` on it, the strongest way that fits; the report says where. |
| WIP | Known, already in progress. | Find the ticket that owns it, or file one. |
| QUESTION | They need an answer. | Answer it in the report. |

A blank quick-notes block records nothing beyond its items' marks.

## Form

```markdown
# Over to you, <name>!

<brief: what this sitting is for, in one or two lines, and what each quick-notes tag means, one short line per tag>
<one line: what to open, where, and on which branch or build>
<sitting <n> of <total>, when there is more than one>
signed off: <each item left out, with where its pass is recorded, or "nothing yet">
proven by: <each command you ran for the checks left off this list, with its result>
Mark each item: [x] completed as expected, [~] completed with changes, [-] failed to complete, [ ] not tested at all.

## <section>

1. [ ] <verb first: what to do> → <what you should see>
   person: <look | feel | real client | second client | extender | hardware | outside account | timing>
   notes:

2. [ ] <...> → <...>
   person: <...>
   notes:

quick notes:
- BUG:
- QUIRK:
- FRICTION:
- UGLY:
- IDEA:
- RULE:
- WIP:
- QUESTION:

## Extra tests

<checks you did outside the list, with their results>

quick notes:
- BUG:
- QUIRK:
- FRICTION:
- UGLY:
- IDEA:
- RULE:
- WIP:
- QUESTION:

## Other

<anything else>

quick notes:
- BUG:
- QUIRK:
- FRICTION:
- UGLY:
- IDEA:
- RULE:
- WIP:
- QUESTION:
```

Each item is one line. A step that needs explaining is two items. Group the items into sections by feature area.
