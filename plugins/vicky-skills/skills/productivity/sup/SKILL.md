---
name: sup
description: Catch the user up in one screen — what got done, what changed, what waits on them, what comes next. Use when the user asks "sup", "what's up", "where are we" or "catch me up", returns after a break, or a long stretch of work ends.
---

# Sup

> _Sup? Read the record, not your memory._

A **catch-up** answers four questions for someone who just walked in. They read it once and know what to do. It covers the time since the user's last message, or since the point they name.

## Steps

1. **Read the record, not your memory.** Check the branch, the commits, open pull requests and the tickets the work touched, now, because other sessions change them. Done when each claim you will make has a fresh command behind it.
2. **Write the four parts**, one line per item, with a short code on each so the user can answer by code:

   ```markdown
   **Done** — <what landed, with its proof: a merged PR, a passing check>
   **Changed** — <decisions made or reversed, and what they replaced>
   **Waiting on you** — <questions and approvals, two options at most, recommendation first>
   **Next** — <the one next action>
   ```

   Leave out an empty part. Done when the whole thing fits on one screen.
3. **Add parked work.** When the user moved away from something unfinished, end with at most three lines: "Still want X?" Count only work they left, not work you found. Done when each parked item is asked once or dropped.
