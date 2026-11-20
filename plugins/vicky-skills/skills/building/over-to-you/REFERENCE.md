# Over to you: reference

Branch-only detail for `SKILL.md`: read **Kits** at step 2, **Quick notes** and **Form** at steps 3 and 5.

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
- When the sitting closes, remove everything the kits made, and commit no kit file, unless the testing standards allow it and say where. When they do, commit it there and only there.

## Quick notes

Every section, Extra tests and Other end with a quick-notes block: one line per tag, each blank. The user fills the lines they need, and repeats a tag on a new line for a second note. On read-back, each tag says what to do:

| Tag | The user means | Do |
| --- | --- | --- |
| BUG | Something is broken or wrong. | Put it on the ticket for the next session, and on the next sitting's list. |
| QUIRK | It works, but something is odd. | Put it on the ticket for the next session. |
| FRICTION | It works, but it feels bad to use. | Put the proposed fix on the ticket for the next session. |
| UGLY | It looks wrong. | Put it on the ticket for the next session, with the project's visual proof to get. |
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
   person: <look | feel | real client | second client, no harness reaches <the gap> | extender | hardware | outside account | timing>
   ran: <checklist.py writes it from the item's ran.sh receipt: `the command` exit 0 at <time>>
   kit: <for an item that reaches a thing: `the exact command` and where to run it>
   notes:

2. [ ] <...> → <...>
   person: <...>
   ran: <...>
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
