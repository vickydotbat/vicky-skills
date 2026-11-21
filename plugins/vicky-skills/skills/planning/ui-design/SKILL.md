---
name: ui-design
description: Design what a screen says and does: choice screens, confirmations, destructive and bulk actions, labels, defaults, contrast and focus. Use before drawing or building any window, page or screen, when drawing-board starts, when reviewing a UI, and when the user says a tool is tedious, asks for a confirmation, or reports a page that "does nothing" or hides what an option gives.
---

# UI design

> _I know what you're thinking: did it grant two skills or three? Show the player before they pick._

`drawing-board` sets where each box sits and how big it is. This skill sets what each box says and what each action does. Every rule below is a check on a design: a design that fails one is not done.

## Steps

1. **Read the data behind the screen.** For each option, row or item the screen shows, read its record (a table, a config, a data file, a 2da) this session, and list every field the user's choice changes: what it grants, costs, changes, or locks out. A kind of field the data holds for no option gets no box: an empty "Grants: none" is noise. Done when each option's list quotes the fields it came from.
2. **Check choices** against "Choice screens" below. Done when every choice on the screen passes each rule, or the design says which rule it breaks and why.
3. **Check actions** against "Actions" below, walking the screen as a user with a hundred items. Done when each action has its count of clicks per item and every rule passes.
4. **Check the basics** below. Done when each one passes or the design names the box that breaks it.
5. **Hand the checks on.** Each check that changed the design becomes a box on the `drawing-board` sketch and a draft example for `examples`. Done when each changed check names its box or its example.

## Choice screens

- **Informed choice**: each option shows what it grants, costs and changes before the user commits, read from its data, not only its prose. A field the choice changes and the screen leaves out is a bug.
- **Like for like**: options sit side by side with the same attributes in the same order, so one look compares them. Past about five options, give a filter or a table.
- **Visible state**: the current pick and its effect show without opening anything.
- **Recognition over recall**: everything the choice needs is on this screen. The user never carries a fact over from another one.
- **Deliberate default**: a preselected option is a nudge. Preselect one only when the choice is required and the default suits most users, otherwise leave none.
- **Cheap exit**: a choice that is hard to undo says so before the commit, and the user can back out of the screen at no cost.

## Actions

- **Hundredth use**: price each action at its hundredth click in one sitting. An extra dialog, scroll or page load is the whole cost of a tool used a hundred times.
- **Ceremony follows reversibility**: a reversible action (hide, archive, mark, tag) asks no confirmation and offers undo in place. An irreversible one (purge, delete, send, publish) confirms once, and says it cannot be undone.
- **One confirmation per intent**: a bulk action confirms once for the whole set, naming its scope and exact count ("Purge 143 pages in Skills: this cannot be undone"). The most dangerous ones ask the user to type a word.
- **Marks as selection**: in a choose-many-then-commit flow, the reversible mark is the selection: mark, review, commit.
- **Act in place**: an action reports where the user stands, keeping scroll position, focus and place in the list. A full reload after each action is a bug.
- **No silent failure**: every action ends in a shown success or a shown failure with its reason. Use the framework's own modal, never the browser's `alert` or `confirm`, which a user can suppress for good.
- **Bulk path**: data that can hold hundreds of items gets an action over a filtered, marked or whole set. It processes items independently, reports each item's outcome, shows progress, can be cancelled between items, never half-applies an item, and works in chunks that cannot time out.
- **Finish the job**: the actions reach the user's goal, not the data model's halfway state. Both steps of a two-step removal sit on the screen where the work happens.
- **Outstanding work**: show the counts that say how much is left, marked and failed.
- **Explained absence**: a control missing for a permission, state or rule says why in its place, and how to earn it.

## Basics

- **User's words**: labels use the user's terms, and a button names its result ("Delete", not "OK").
- **Hierarchy**: size, contrast, spacing and grouping put the most important thing first. Detail sits one level down, never more than two.
- **Not colour alone**: colour never carries a meaning by itself (WCAG 2.2 1.4.1).
- **Contrast**: text holds at least 4.5:1 against its background (WCAG 2.2 1.4.3).
- **Visible focus**: keyboard and pad focus always shows (WCAG 2.2 2.4.7), and every control is reachable without a mouse.
- **Target size**: a pointer target is at least 24 by 24 CSS pixels, or the screen's equivalent (WCAG 2.2 2.5.8).
- **Consistency**: the same word, control and order mean the same thing on every screen.

Charter: C1, C2 ([CHARTER.md](../../CHARTER.md)).
