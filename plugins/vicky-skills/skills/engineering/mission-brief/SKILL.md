---
name: mission-brief
description: "Turn the conversation so far into a spec, then into a star chart of tickets with Given / When / Then examples. No interview: it writes down what the conversation already settled."
disable-model-invocation: true
---

# Mission brief

> _Your mission, should you choose to accept it: write down what we already decided, then slice it._

A **mission brief** writes down what a conversation already settled, and files it. It asks no new questions: an open question goes into the spec as an anomaly, never into chat. The words and ticket forms are in [STAR-CHART.md](../lay-course/STAR-CHART.md), and the tracker's commands in `docs/agents/issue-tracker.md`. If that file is missing, tell the user to type `/first-contact`, and stop.

## Steps

1. **Write the spec** from the conversation and the code it touches: the mission in three sentences at most, what the user will see, the decisions made and why, what is out of scope, and the open questions. Use the repo's glossary words. Then cut it into **slices**: each one a thin path through every layer that can be shown working on its own, sized to one session, with the slices it waits on. Draft each slice's Given / When / Then examples with `examples`, steps 1 and 2. Done when every settled point is in the spec, and every slice has its examples and its blockers.
2. **Hand it to the user** with `red-pen`: the spec, then one section per slice holding its examples. The user edits, cuts or reorders there, before anything is filed. Done when you hold the user's text.
3. **File it** as a star chart in the repo's tracker, from the user's text: the chart body from the spec, one star per slice holding the `examples` drafts the user left, an anomaly per open question, and the blocking links between them. Draw the chart. Done when the chart shows every star and anomaly with its blockers.
4. **Report** the chart's link and its frontier, then ask the user to type `/lay-course` to work the chart, or say "warp" to clear it. Done when the reply holds the link and the next step.

## Examples the user cut

A slice whose examples the user cut is filed with "Examples: not written yet", never with examples the user did not see. `examples` writes them later, before that star is built.
