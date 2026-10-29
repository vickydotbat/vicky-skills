---
name: ui-design-101
description: Design the actions in an interface — buttons, confirmations, destructive operations, bulk edits, admin and moderation tools. Use when building or reviewing anything a user clicks repeatedly, anything that deletes or hides data, any list of rows with per-row actions, or when the user says a tool is tedious, asks for a confirmation dialog, or reports an interface that "does nothing".
---

# UI design 101: actions

This skill covers what happens when someone clicks, and above all what happens on the **hundredth click**. Visual design is a different skill. Every rule below is a property you can check, and an interface that fails one is not done.

## Steps

1. **Count the use.** For each action, estimate how often one person does it in one sitting. Done when every action has a number.
2. **Walk it with a hundred items.** Apply every rule below to every action. Done when each action passes each rule, or the miss is written down with its fix.
3. **Write the checks as examples.** Turn each rule an action must meet into a Given / When / Then example and hand them to the `examples` skill, so `do` builds the interface red first:

   ```
   Given a page of 40 marked rows
   When the user archives them
   Then one confirmation names "40 rows", and the list keeps its scroll position
   ```

   Done when every action with a rule at stake has an example.

## Rules

### Price an action at its hundredth use

An extra dialog, scroll or page load costs nothing once and an afternoon a hundred times. When one person does an action more than a handful of times in a sitting, its per-use cost is the whole design problem. A tool can be pleasant to demo and brutal to use, because its builders click each thing twice.

### Ceremony follows reversibility

Undo beats confirm. A confirmation asks the user to be sure in advance. An undo lets them be wrong cheaply.

- **Reversible** (hide, archive, mark, tag): no confirmation. Do it, show it happened, and offer undo in the same spot.
- **Irreversible** (purge, permanent delete, send, publish): confirm once, and say plainly that it can't be undone.

A confirmation on a reversible action teaches the user to dismiss dialogs unread, and then they dismiss the one that matters.

### One confirmation per intent

A user removing a hundred things decided once, so ask once. That confirmation names the scope and the exact count ("Purge 143 pages in Skills. This can't be undone."). For the most dangerous actions, ask the user to type something deliberate instead of clicking.

### The reversible state is the selection

Where a flow is "choose many, then commit", the reversible action is the selection: mark, review, commit. Marks beat checkboxes: they survive a reload, a colleague sees them, they undo one at a time, and the user watches the set grow.

### Act in place

An action shows its result where the user is: re-render the row or card, and keep scroll position, focus and their place in a long list. A full page reload after each action makes the user find their place again a hundred times.

### Every action ends visibly

Each action ends in success shown, or failure shown with a reason and what to do next. An action that can quietly do nothing is the worst kind of interface bug: the user keeps working and finds out later that none of it happened.

- **Pending is visible.** A slow action shows it is working, and its control is disabled until it ends, so a double click can't run it twice.
- **An optimistic update rolls back visibly** when the server refuses it.
- **Own your dialogs.** A browser lets a user suppress native `alert`, `confirm` and `prompt` for good. Code that reads a suppressed `confirm` sees "cancelled" and does nothing until a reload. Use the framework's own modal.

### Bulk work has a bulk path

Where the data can hold hundreds of items, offer one action over the whole set: a filter, the marked items, or a namespace. A per-item button is not a bulk feature, however fast the loop.

- Process items independently. One failure doesn't abandon the rest.
- Report each item: done, failed with a reason, or skipped with a reason.
- Show progress, and let the user cancel between items.
- Leave every item fully done or fully untouched.
- Chunk the work so a large set can't time out the request.

### Finish the user's job

Match the actions to the goal, not the data model. Hidden isn't deleted, unpublished isn't removed, and archived isn't gone. Where a two-step model exists for safety (hide, then remove), both steps belong on the screen where the work happens.

### Show what's left

Show the counts that say how much work remains: marked, remaining, failed. A cleanup task needs a visible end.

### Explain a missing action

When a control is absent because of a permission, a state or a rule, say so in its place, with the way to earn the action where there is one. An unexplained gap reads as a bug.

### Place by danger

The primary action sits where the eye lands. A destructive action sits apart from it, styled as dangerous, never as the default button, and never where the primary one was a moment ago.

### Every repeated action has a keyboard path

An action someone repeats has a keyboard path, focus moves somewhere sensible after it, and a screen reader announces its result.

### An empty state says what to do

An empty list says why it's empty and offers the action that fills it.
