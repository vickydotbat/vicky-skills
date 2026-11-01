---
name: summit
description: Count tickets opened versus closed in a repo's tracker and give the 30-day verdict, A, B or C. Use when the session-start hook asks for the summit count, when the user asks "summit", "are we closing more than we open" or for the backlog trend, and when `captains-log` or `cerebro` reads the trend.
---

# Summit

> _Discoveries never stop. The summit is closing more than you open._

The **summit** is tickets closed against tickets opened in one repo's tracker. The 30-day **verdict**: A when closed is more than 10% above opened, C when it is more than 10% below, B in between. The record keeps one 30-day count per repo per day, in the plugin's data folder, through `${CLAUDE_PLUGIN_ROOT}/scripts/summit.sh`.

## Steps

1. **Count with the tracker's "since" operations.** Run "List items created or changed since <time>" and "List items closed since <time>" from `docs/agents/issue-tracker.md`, for the time the hook or the user names. Opened is the new items only. Never count from snapshots. Done when you hold the opened and closed numbers.
2. **Record or show.** For a 30-day count, run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/summit.sh record <opened> <closed> <since-opened> <since-closed>`, with the counts since the user's last session as the last two. When the hook says today's count is kept, run `summit.sh show <since-opened> <since-closed>` instead. Both print a `summit:` line, which the viewscreen band shows. Done when the script printed its line.
3. **Report the line** in the reply, as the script printed it, without the `summit: ` prefix. On B or C, propose one way to close more, never a way to find less. Done when the reply holds the line.
