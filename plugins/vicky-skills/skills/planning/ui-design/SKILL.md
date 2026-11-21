---
name: ui-design
description: Design what a screen says: choice screens, side-by-side options, contrast and target size. Use before drawing or building any window, page or screen, when drawing-board starts, when reviewing a UI, and when the user reports a page that hides what an option gives.
---

# UI design

> _I know what you're thinking: did it grant two skills or three? Show the player before they pick._

`drawing-board` sets where each box sits and how big it is. This skill sets what each box says. Every rule below is a check on a design: a design that fails one is not done.

## Steps

1. **Read the data behind the screen.** For each option, row or item the screen shows, read its record (a table, a config, a data file, a 2da) this session, and list every field the user's choice changes: what it grants, costs, changes, or locks out. A kind of field the data holds for no option gets no box: an empty "Grants: none" is noise. Done when each option's list quotes the fields it came from.
   Proven by: plugins/vicky-skills/evals/ui-design/pick-page-side-by-side
2. **Check the design** against every rule below, and add a box or a line to the design for each rule it fails. Done when every rule passes, or the design names the rule it breaks and why.
   Proven by: plugins/vicky-skills/evals/ui-design/pick-page-side-by-side

## Choice screens

- **Informed choice**: each option shows what it grants, costs and changes before the user commits, read from its data, not only its prose. A field the choice changes and the screen leaves out is a bug.
   Proven by: plugins/vicky-skills/evals/ui-design/pick-page-side-by-side
- **Like for like**: options sit side by side in one table, with the same attributes in the same columns, so one look compares them.
   Proven by: plugins/vicky-skills/evals/ui-design/pick-page-side-by-side

## Basics

- **Accessible basics**: text holds at least 4.5:1 contrast against its background (WCAG 2.2 1.4.3), and a pointer target is at least 24 by 24 CSS pixels (2.5.8). The design states both.
   Proven by: plugins/vicky-skills/evals/ui-design/pick-page-side-by-side

Charter: C1, C2 ([CHARTER.md](../../CHARTER.md)).
