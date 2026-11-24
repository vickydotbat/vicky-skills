---
name: groundhog-day
description: "File one bug as a ticket a reader takes in at a glance: a short summary, screenshots, steps to reproduce, more cases and related issues. Use when the user asks to file, report, log or write up a bug, or when a bug found mid-work must wait for a ticket."
---

# Groundhog day

> _Same steps, same bug, every time. Write it down so the reader lives it once._

A **bug ticket** costs its reader less time than it cost to write: the reader sees what breaks, replays it, and finds its neighbours without asking. It holds one bug. Planned work, a feature or a set of slices goes to `mission-brief`. The tracker's commands are in `docs/agents/issue-tracker.md`. If that file is missing, tell the user to type `/first-contact`, and stop.

## Steps

1. **One bug, one ticket.** Search the tracker with its Find action for the bug's words, its screen and its error text, and search the open pull requests. Read each hit whole. A ticket on the same bug gets the new facts as a comment, and no second ticket is filed: go to step 5 with its link. Done when the search terms and their hits are listed, and no open ticket covers the same bug.
2. **Replay it.** Run the steps yourself where you can reach the system, from a clean start, and note what you see. Try the closest cases: a neighbouring input, screen or setting, and say which break and which don't. A step you can't run stays in the ticket marked `unchecked`. Done when each step reads as seen or `unchecked`, and at least one more case is tried or named `unchecked`.
3. **Screenshots.** Show what it looks like now and what it should look like: take a picture with `by-eye` for a page, or use the one the user gave. Attach it the way the tracker doc's actions say. With no way to attach, write `none, because <reason>` and describe in one line what the picture would show. Done when the section holds a picture the tracker shows or its `none` line.
4. **Write the ticket** in the template below, with `human-voice`. Brief: the summary holds two sentences at most, and each step one action. Use the tracker's bug kind or label when its doc names one, and its plain ticket otherwise. Keep local paths and machine names out, as `loose-lips` says. Done when every section is filled or says why it is empty.
5. **File it** with the tracker's File action, then read it back. Done when the reply holds the ticket's link.

## Template

```markdown
# <what breaks, where>

## Summary

<what happens>. <what should happen>.

## Screenshots

<now> | <should be>

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
