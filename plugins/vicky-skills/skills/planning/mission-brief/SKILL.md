---
name: mission-brief
hands-off: [away-team, groundhog-day, red-pen]
description: "Chart a plan: turn what the conversation settled into a star chart and its stars. Use whenever the user asks to turn a plan or conversation into tickets, to chart or slice settled work, or to convert or import tickets made by another tool or planner. One bug, task or issue goes to groundhog-day. No interview: it writes down what is already settled."
---

# Mission brief

> _Your mission, should you choose to accept it: write down what we already decided, then slice it._

A **mission brief** writes down what a conversation already settled, and files it. It is the way a plan is charted, `groundhog-day` is the way one ticket or issue is filed, a bug or not, and `away-team` is the way one research note is: `ticket-filing-guard` refuses `plane file`, `tea issues create` and `gh issue create` until one of them has started. Tickets made by another tool or planner are its input too: re-slice them, never copy them across. It asks no new questions: an open question goes into the spec as an anomaly, never into chat. The words and ticket forms are in [STAR-CHART.md](../../commands/lay-course/STAR-CHART.md), and the tracker's commands in `docs/agents/issue-tracker.md`. If that file is missing, tell the user to type `/first-contact`, and stop.

**One ticket goes to groundhog-day.** When what is settled is one bug, task or issue, start `groundhog-day` with it and file nothing here: mission-brief files no lone ticket, and every ticket it files sits on the chart.
Proven by: plugins/vicky-skills/evals/mission-brief/docs-only-files-a-task

## Check first

Before step 1 writes a word, check what the brief rests on. A ticket written from memory carries invented premises. Do all four:

- **Source material.** Read the rulebook, spec, docs, decision records and API each claim rests on, and quote the line. Start `away-team` for a fact no source in hand answers.
- **The tracker.** Search it for every term and claim the brief makes: tickets, comments and decisions that already settle it. A premise decided there binds the brief, quoted, and is never re-opened.
- **An existing ticket.** Search for a ticket on the same work. Read it whole, with its comments. The brief replaces or amends it: it keeps what the comments settled and goes on that ticket as a comment, never as a second ticket.
- **The codebase.** Search it for anything that looks like what the brief names, by behaviour as well as by name (a "touch attack" that is already a spell attack). Search the open pull requests too, since the checkout may lack work they hold. What exists is reused or extended, never rebuilt.

Done when each claim in the brief has its quoted source, a tracker search names the tickets it found or says it found none, and a codebase search names what looks like it or says it found nothing.

## Steps

1. **Write the spec**, after the checks above, from the conversation and the code it touches: the mission in three sentences at most, what the user will see, the decisions made and why, what is out of scope, and the open questions. Sort what the slices rest on into the four Rumsfeld boxes, as "Sorting the knowns" in STAR-CHART.md says, each with its action: **known knowns**, stated in a source, become the spec and the slices' examples; **known unknowns**, the open questions, each become an anomaly or an away team; **unknown knowns**, rules the user holds but never wrote down and how the work crosses existing features, become `Confirm:` examples for the user to tick; **unknown unknowns** can't be listed, so name the riskiest slice and draft its edge, mode and stillness examples, or file a probe. Use the repo's glossary words. Then cut it into **slices** and draft their examples. A slice whose whole change is prose (a doc, a skill's guidance, a decision record) is a **task** on the chart: it gets a `Done when` line and no examples, since prose is never tested or proven. Draft the others' examples as STAR-CHART.md's "Filing a star" steps 1 and 2 say, each with the slices it waits on. Where they land follows "Where work lands" in [the lay-course skill](../../commands/lay-course/SKILL.md). Quote each value an example names from its source of record, and read the slices' examples against each other for a contradiction, as `examples` step 2 says. Done when every settled point is in the spec, each of the four boxes holds its items or says why it is empty, every slice has its examples and its blockers, and every named value has its quoted source.
   Proven by: plugins/vicky-skills/evals/mission-brief/check-first
2. **Shard it**, as [STAR-CHART.md](../../commands/lay-course/STAR-CHART.md)'s "Sharding" says. Done when the chart passes "Sharding".
3. **Hand the examples to the user** with `red-pen`, as "Filing a star" step 3 says: one section per slice holding its examples, before anything is filed. The spec stays out of the page. When the caller skips `red-pen`, mark each example "unapproved draft". Done when you hold the user's examples, or each example is marked.
4. **File it** as a star chart in the repo's tracker: the chart body from the spec with its Knowns section, one star per slice holding the `examples` drafts the user left, one task per prose-only slice with its `Done when` line, an anomaly or away team per known unknown, an away team per unknown known that is not a `Confirm:` line, and the blocking links between them. Draw the chart, and set its label by [STAR-CHART.md](../../commands/lay-course/STAR-CHART.md)'s "Ready to warp". Done when the chart shows every star and anomaly with its blockers, and the label matches.
5. **Report** the chart's link and its frontier, then ask the user to type `/lay-course` to work the chart, or say "warp" to clear it. When another skill's run called you mid-flight and its next step waits (a warp filing a new star, `post-mortem` filing a follow-up), send no report and no ask: hand the chart's link to that step, and make this same response carry its tool call.
   Proven by: plugins/vicky-skills/evals/mission-brief/returns-to-warp
   Done when the reply holds the link and the next step, or, for a caller, the caller's next tool call is in this response.

## Examples the user cut

A slice whose examples the user cut is filed with "Examples: not written yet", never with examples the user did not see. `examples` writes them later, before that star is built.

Charter: C1, C6, C9 ([CHARTER.md](../../CHARTER.md)).
