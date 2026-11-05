---
name: mission-brief
description: "File tickets, issues or a star chart from what the conversation settled. Use whenever the user asks to file, open or write up tickets or issues, to turn a plan or conversation into tickets, or to convert or import tickets made by another tool or planner. No interview: it writes down what is already settled."
---

# Mission brief

> _Your mission, should you choose to accept it: write down what we already decided, then slice it._

A **mission brief** writes down what a conversation already settled, and files it. It is the only way a ticket is filed: `ticket-filing-guard` refuses `plane file`, `tea issues create` and `gh issue create` until it has started. Tickets made by another tool or planner are its input too: re-slice them, never copy them across. It asks no new questions: an open question goes into the spec as an anomaly, never into chat. The words and ticket forms are in [STAR-CHART.md](../lay-course/STAR-CHART.md), and the tracker's commands in `docs/agents/issue-tracker.md`. If that file is missing, tell the user to type `/first-contact`, and stop.

## Check first

Before step 1 writes a word, check what the brief rests on. A ticket written from memory carries invented premises, and misses a premise already decided elsewhere. Do all three:

- **Source material.** Read the rulebook, spec, docs, decision records and API each claim rests on, and quote the line. Start `away-team` for a fact no source in hand answers.
- **The tracker.** Search it for every term and claim the brief makes: tickets, comments and decisions that already settle it. A premise decided there binds the brief, quoted, and is never re-opened.
- **The codebase.** Search it for anything that looks like what the brief names, by behaviour as well as by name (a "touch attack" that is already a spell attack). What exists is reused or extended, never rebuilt.

Done when each claim in the brief has its quoted source, a tracker search names the tickets it found or says it found none, and a codebase search names what looks like it or says it found nothing.

## Steps

1. **Write the spec**, after the checks above, from the conversation and the code it touches: the mission in three sentences at most, what the user will see, the decisions made and why, what is out of scope, and the open questions. Sort what the slices rest on into the four Rumsfeld boxes, as "Sorting the knowns" in STAR-CHART.md says: each open question is a known unknown. Use the repo's glossary words. Then cut it into **slices** and draft their examples, as STAR-CHART.md's "Filing a star" steps 1 and 2 say, each with the slices it waits on. Where they land follows "Where work lands" in [the lay-course skill](../lay-course/SKILL.md). Quote each value an example names from its source of record, and read the slices' examples against each other for a contradiction, as `examples` step 2 says. Done when every settled point is in the spec, every slice has its examples and its blockers, and every named value has its quoted source.
2. **Hand the examples to the user** with `red-pen`, as "Filing a star" step 3 says: one section per slice holding its examples, before anything is filed. The spec stays out of the page. Done when you hold the user's examples.
3. **File it** as a star chart in the repo's tracker: the chart body from the spec with its Knowns section, one star per slice holding the `examples` drafts the user left, an anomaly or away team per known unknown, an away team per unknown known that is not a `Confirm:` line, and the blocking links between them. Draw the chart. Done when the chart shows every star and anomaly with its blockers.
4. **Report** the chart's link and its frontier, then ask the user to type `/lay-course` to work the chart, or say "warp" to clear it. Done when the reply holds the link and the next step.

## Examples the user cut

A slice whose examples the user cut is filed with "Examples: not written yet", never with examples the user did not see. `examples` writes them later, before that star is built.

Charter: C1, C6 ([CHARTER.md](../../CHARTER.md)).
