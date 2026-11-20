---
name: summit
description: Typed by the user as /summit, for the detailed breakdown of tickets opened versus closed in a repo's tracker. Use when the user types summit. The session-start hook counts the summit and the band shows it with no agent work; any other ask for the trend reads `summit.sh show`.
disable-model-invocation: true
---

# Summit

> _Discoveries never stop. The summit is closing more than you open._

The **summit** is tickets closed against tickets opened in one repo's tracker. The 30-day **verdict**: A when closed is more than 10% above opened, C when it is more than 10% below, B in between. The `summit.sh auto` session-start hook counts it with the `Summit count:` line of `docs/agents/issue-tracker.md`, and the viewscreen band shows the line it keeps. A repo without that line has no summit. This skill gives the breakdown behind the line.

## Steps

1. **Read the kept line.** Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/summit.sh show` from the repo. On `nothing counted yet`, say the repo's tracker doc needs a `Summit count:` line, as first-contact's tracker docs give it, and stop. Done when you hold the line.
   Proven by: plugins/vicky-skills/evals/summit/typed-breakdown
2. **List the items.** When the tracker has a "List notes off the tracker" operation, run it first and name each note it lists: such a note is missing from both counts. Run "List items created or changed since <time>" and "List items closed since <time>" from `docs/agents/issue-tracker.md`, for the time in `$(git rev-parse --path-format=absolute --git-common-dir)/summit-since`, where the hook kept the start of the user's last session, and for 30 days ago. An empty file means no earlier session: list the 30 days only. Done when you hold the opened and closed items of both spans.
   Proven by: plugins/vicky-skills/evals/summit/typed-breakdown
3. **Report.** Give the line without its `summit: ` prefix, then the items opened and closed since the last session, then the 30-day counts by kind or label when the tracker has them. On B or C, propose one way to close more, never a way to find less. Done when the reply holds the line and the lists.

Proven by: plugins/vicky-skills/evals/summit/typed-breakdown

Charter: C6 ([CHARTER.md](../../CHARTER.md)).
