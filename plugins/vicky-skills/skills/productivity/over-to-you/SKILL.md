---
name: over-to-you
description: Hand the live checks only a person can do to the human, as a checklist page in their browser. Use when a change needs a real client, a look, a feel, real hardware or an outside account to prove, or the user asks to test something themselves.
---

# Over to you

> _Over to you in the field. Everything the agent can run, it already ran._

Everything the agent can run, it runs, and only the rest goes **over to you**. A page the agent can look at itself goes through `by-eye` first; only a look a person must judge, such as whether it feels right, comes here. During a `council-of-elrond`, the list waits until Frodo has chosen the road.

## Steps

Read the repo's `TESTING_STANDARDS.md` first: it wins over this skill's defaults.

1. **Pick the human-only checks across the whole branch.** Source items from the whole branch, never from the latest work alone: every ticket the branch, its commits or its pull request body names, and every feature area in `git diff --stat <base>...HEAD`. Keep an item only when no command can prove it, and when an item is on the list only because no test reaches its layer (no player session, no client), name that missing seam in the report and on the ticket, so the next sitting has fewer hand checks: what a person sees or feels in the real client, real hardware, an outside account, a timing a test can't hold. Run every other check yourself first: an outcome a test could assert (a stack merges, a line is or isn't sent, an item lands in a cell) becomes that test, run green on the branch, and never an item. Run the repo's test for the whole branch too (its `TESTING_STANDARDS.md` names the command), so no test the branch added reaches a sitting unrun. An item judged by feel that has a measurable proxy (a time, a count, a size) gets the measurement first, and the item carries the number beside the feel check. A retest of an item that failed gets a test that reaches the layer the user saw fail first. When no test can reach it, the item names where the test stops ("this test stops at the atlas file; the shader is unproven"). Leave out an item the user already passed only when the pass is on record: a verdict on the pull request's Proof section, a ticket comment, or an earlier over-to-you file the user closed with a pass. Each window, panel or tab the branch adds gets an item that it shows its content (its images, swatches or lists), not only that it opens. Wording is no item: each player-facing or UI text the branch writes or changes goes in the effort's `red-pen` draft file instead. Done when every ticket and changed feature area has an item, a recorded sign-off, or a reason no person can check it, each item left fails the question "could a command prove this?", and the draft file holds every new text. The `step-hint` hook repeats this when the skill starts.
2. **Get the stage ready, for every sitting.** A sitting with no branch, such as a client-side override or a config change outside the repo, still has a stage and kits: skip only the branch moves. When the sitting has a branch, the user tests in the clone itself (the repo's first working tree, never a worktree), so commit and push the branch, remove its worktree (git checks a branch out in one place only), then switch the clone to the branch. When the clone holds uncommitted changes, stop and ask the user what to do with them. For every sitting, build what the checks run on, install the built copy where the user tests it, and start its servers (the repo's local dev stack, as its docs say), then prove each one up and answering with a command, such as a health check or a log line, and name that command on the `proven by:` line, or `no server` when nothing runs. When a client loads content from its own copy (an asset pack, a plugin or override folder, an installed build, an app or browser cache), the server proves nothing about that copy: quote on the `proven by:` line the copy's hash or version beside the release's. Name there too what the stage loads (a world, module, profile, config or workspace), and show it lists every pack, plugin or extension the checks need: a default one can leave one out. Seed the data, so the human starts at item 1 with no setup. Stock every item: make the props, the state and the scripts each check needs (two stacks of arrows that differ in one local variable, a character at the right level), or give the item the one command that makes them, so the user never builds a prop by hand. Every item whose action reaches a thing (spawn, give, create, place, equip, summon, seed, load) gets a `kit:` line holding the exact command the user runs, in backticks, and where to run it (`/runscript paper_icon` in the game chat as a DM, `./seed.sh` in the user's terminal). A resref or blueprint name alone is no kit. Every step the user takes goes on the page, on its item: a step said only in chat is lost when the page opens. Make kits by the means the project's docs describe, in a scripting language the server runs where it has one: a test module, a seed script, a test-only script folder, or the `Test props:` line in `TESTING_STANDARDS.md`. Build each kit as "Kits" below says. Then run every kit once against the live stage, and read its output and the server log: a kit counts only when it ran with no error, abort or timeout. With no place named, use something disposable (a script, a scratch save, a throwaway record), remove it after the sitting, and ask the user where test props live from now on. Write the answer as the `Test props:` line in `TESTING_STANDARDS.md`. A prop goes in the test surface or a disposable, never in content that ships. For a retest, prove the `proven by:` line again for the fix: built, on the server and on the client. A retest after a failed sitting opens only once you have found the cause without the client and say on the `proven by:` line what proves it; a second sitting on a guess wastes the user's time again. Done when a command proves every server the checks run on is up and answering, a branch sitting has the clone on the branch with no worktree left for it, the opening line can say where everything is, and every item that reaches a thing has a `kit:` line whose kit ran clean on the live stage, and the `proven by:` line proves every copy a client loads itself.
3. **Write the checklist** with `python3 <this skill's folder>/scripts/checklist.py <spec.json> <file>`, never by hand: put the sitting's lines in a JSON spec as the script's header shows, written with `human-voice`, and the script writes the form below to `<file>`, `over-to-you-<topic>.md` in the session scratch folder, `/tmp/$CLAUDE_CODE_SESSION_ID` (the script refuses a file loose in the shared temp folder). Check each item's expected result against the rules the user stated in this effort and its approved examples, and fix any result that contradicts one before the page opens: a checklist written from the build alone tests the bug. Use seven items or fewer per sitting. A longer list becomes numbered sittings, one file each (`over-to-you-<topic>-1.md`, `-2.md`), and none is dropped. Take items from the approved examples where they exist, one each. Address the human by name, or "Bob" when you don't know it. Done when `checklist.py` exits 0, which also means `scripts/lint-checklist.py` passed, and every step the user must take sits on an item line or its `kit:` line. An item you can run yourself, such as a grep of a log or a read of a file, is no item: run it, and put its result on the `proven by:` line. The lint refuses a terminal read. Each `person:` line names one reason only a person can check the item: look, feel, real client, second client, extender, hardware, outside account or timing. The lint also refuses an item that spawns, gives, creates, places, equips, summons, seeds or loads a thing with no `kit:` line.
4. **Open it** the way `red-pen` step 2 opens a draft file, in the same turn the code it checks lands, with its 🚪 line, and wait for the close. When the effort's draft file holds sections, open it with `red-pen` first and write its text back, so the sitting checks the approved wording. Done when the user pressed Done, the editor has exited, or the user said done.
5. **Read it back.** Each item carries its mark and notes, and Extra tests and Other hold anything the user added. Act on each quick note as "Quick notes" below says, by its tag. Take every item marked `[~]`, `[-]` or `[ ]` back into the loop (`never-lupus` to find the cause, `do` to fix it). An item that fails a second time means the diagnosis is wrong, not the fix: it goes to `never-lupus` for a loop the agent runs alone, and no third sitting checks it until that loop has gone red and then green. Record each verdict in both places: the pull request's Proof section, and a comment on each ticket whose approved example the item checks, naming its E-number. A later session reads the ticket for an example's state, and it finds nothing there when the verdict lives only on the pull request. Write each finding the user names beyond the item list (a hitch, a look, a second bug) to the ticket as its own line too, and keep it open until a commit fixes it or a `Waits on:` line parks it: a finding that lives only in chat comes back at the next sitting. Then clean up as "Kits" says. Done when every item and every named finding has a verdict on record and nothing the kits made is left.

## Kits

A kit is what one check needs to run: the things it acts on, their state, and the script that makes them.

- Build each check its own things, from scratch: a mark to pickpocket is a creature spawned for that check, friendly, in reach and carrying what the check takes, and never borrow one already in the world. <!-- kept 2026-10-31: a pickpocket mark built fresh for its check passed first time, "Perfect", after a borrowed one failed -->
- Give plain props: the default thing, with no extra properties, limits or permissions. A stock template can carry a requirement the tester can't meet, so add a property only when the check is about it.
- A diagnostic kit that changes live state targets the narrowest scope it can, names that scope on its item, and puts back what it set before the next check. A blank or wildcard target reaches everything, and its leftovers look like a bug.
- Collect first, then change: a kit that removes from a collection while it walks that collection can skip items or never finish.
- Check each thing a kit names against the built content before the sitting: it exists there, and it is the kind the check needs (an armor, not clothing). A kit that runs clean on the wrong kind of thing still wastes the sitting.
- A check on a part of a thing (a layer, a slot, a field) measures that the part exists on the thing the kit uses before the page opens, and the `proven by:` line quotes the measure ("chest 7 is 46% cloth 1, and its model names only itself").
- A kit that turns state on (a toggle, a debug view, a mode) gets a later item that turns it off, with the command and what the user sees once it is off. The lint refuses a toggle with no later off item.
- A kit command for a console or tool you can't run yourself is quoted from a source (its docs, a stock file, the user's own earlier use), named on the item's `source:` line. The lint refuses a console kit with no `source:` line.
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
proven by: <the command that shows each server up and answering, and each command you ran for the checks left off this list, with its result>
Mark each item: [x] completed as expected, [~] completed with changes, [-] failed to complete, [ ] not tested at all.

## <section>

1. [ ] <verb first: what to do> → <what you should see>
   person: <look | feel | real client | second client | extender | hardware | outside account | timing>
   kit: <for an item that reaches a thing: `the exact command` and where to run it>
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

Charter: C2, C5 ([CHARTER.md](../../CHARTER.md)).
