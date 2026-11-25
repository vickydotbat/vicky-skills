---
name: groundhog-day
hands-off: [by-eye, human-voice, mission-brief]
description: "File one bug as a ticket a reader takes in at a glance: a short summary, screenshots, steps to reproduce, more cases and related issues. Use when the user asks to file, report, log or write up a bug, or when a bug found mid-work must wait for a ticket."
---

# Groundhog day

> _Same steps, same bug, every time. Write it down so the reader lives it once._

A **bug ticket** costs its reader less time than it cost to write: the reader sees what breaks, replays it, and finds its neighbours without asking. It holds one bug. Planned work, a feature or a set of slices goes to `mission-brief`. The tracker's commands are in `docs/agents/issue-tracker.md`. If that file is missing, tell the user to type `/first-contact`, and stop.

## Steps

1. **One bug, one ticket.** Search the tracker with its Find action for the bug's words, its screen and its error text, and search the open pull requests. Read each hit whole. **Same bug:** an open ticket on the same bug gets the new facts as a comment with the tracker's Comment action, and no second ticket is filed: reply with its link and stop. Done when the search terms and their hits are listed, and either no open ticket covers the same bug or the comment is on the one that does.
   Proven by: plugins/vicky-skills/evals/groundhog-day/same-bug
2. **Replay it.** Run the steps yourself where you can reach the system, from a clean start, and note what you see. Try the closest cases: a neighbouring input, screen or setting, and say which break and which don't. A step you can't run stays in the ticket marked `unchecked`. Done when each step reads as seen or `unchecked`, and at least one more case is tried or named `unchecked`.
   Proven by: plugins/vicky-skills/evals/groundhog-day/five-sections
3. **Screenshot the bug.** One picture of the bug as it is now: take it with `by-eye` for a page, or use the one the user gave. What should happen stays in words, in the Summary: a report has no fix to picture, and the fix's pull request pairs this shot, as its before, with its after. Attach it the way the tracker doc's actions say. With no way to attach, write `none, because <reason>` and describe in one line what the bug looks like. Done when the section holds a picture the tracker shows or its `none` line.
   Proven by: plugins/vicky-skills/evals/groundhog-day/five-sections
4. **Write the ticket** in the template below, with `human-voice`. Brief: the summary holds two sentences at most, and each step one action. Use the tracker's bug kind or label when its doc names one, and its plain ticket otherwise. Keep local paths and machine names out, as `loose-lips` says. Done when every section is filled or says why it is empty.
   Proven by: plugins/vicky-skills/evals/groundhog-day/five-sections
5. **File it** with the tracker's File action, then read it back. Done when the reply holds the ticket's link.
   Proven by: plugins/vicky-skills/evals/groundhog-day/five-sections

## Template

```markdown
# <what breaks, where>

## Summary

<what happens>. <what should happen>.

## Screenshots

<the bug as it looks now>

## Steps to reproduce

1. <one action>
2. <one action>
3. <what you see>, where <what should be seen>

## More cases

- <another place it shows up>
- <the closest case where it does not>

## Related issues

- <ticket or pull request on the same thing>, or none found, by <the search>
```

Charter: C3, C9, C10 ([CHARTER.md](../../CHARTER.md)).
