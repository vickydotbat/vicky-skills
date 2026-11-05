# Gates

A **gate** is any stop that waits on the user: an answer, an approval, a merge, a review, a draft page open in their browser. Every skill waits at a gate the same way.

0. **Check what the user already said.** Before a gate opens, read the user's statements in this effort: a deferral ("that can wait"), a rule, an approval on a page. When one covers the case, it settles it: apply it, quote it in the report, and open no gate. Done when the gate's question has no statement of the user's that answers it.
1. **Ask once.** The message's first line is `🚪 Waiting on you: <the one thing>`. Under it: what the thing does in one plain line, your pick when you hold one, and how the user answers (a word in chat, a page to close, a pull request to merge). The `gate_notify` hook turns that line into a desktop notification.
2. **Watch.** Run `${CLAUDE_PLUGIN_ROOT}/scripts/watch.sh '<check>'` under the Monitor tool. The check reads the gate's own state: the pull request's state for a merge or review, the page's lock for a draft. An answer in chat has no state to read: watch with `--rounds 30` and a check that never passes (`false`), so the watch is a 15-minute timer, and stop it with TaskStop when the answer arrives. When the check passes, go on unasked: a merge or approval you watched for needs no "go" from the user as well.
3. **Work on what doesn't wait.** Never end the turn at a gate: a reply with no tool call ends the run.
4. **Repeat** the `🚪` line every 15 minutes of waiting.
5. **When the watch ends unanswered**: a gate with a pick that opens it (an approval, a draft, a cheap choice) takes the pick, says "Going with <pick>", and records it. A cheap pick never parks on a ticket as `Waits on: you`. A gate with no pick, such as confirming an objective, ends parked, never guessed: write a `Waits on: <the one thing>` line into its ticket or the pull request, and go on with the rest. With nothing left, end on a report of what waits and on whom.
