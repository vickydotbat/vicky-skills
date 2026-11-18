# Gamma shift briefs

For [SKILL.md](SKILL.md) step 4: the text each batch subagent gets.

## Subagent brief

```text
Build <tickets>, in this order, one after another, onto one draft pull request. You work alone: no question reaches the user, and you dispatch no agent.
1. Claim the ticket with "Claim a waiting ticket" in docs/agents/issue-tracker.md, before any other write. A claimed ticket drops off every other session's waiting list.
2. Read the agent file (CLAUDE.md or AGENTS.md) of the repo the ticket changes. When it says to commit straight to main, this is a trunk repo: git pull --rebase on main, build there, push to main, and open no pull request. Otherwise git fetch --prune, then git switch --detach origin/gamma-shift-<date>, or origin/main when origin has no such branch yet. Push every commit with git push origin HEAD:gamma-shift-<date>. When that branch has no pull request, open one as a draft titled "Gamma shift <date>", with its body written by ship-it; otherwise add this ticket to its body with ship-it, keeping its sections. Never commit to any other branch.
3. No approved examples on the ticket: write drafts with `examples` steps 1 and 2 only, commit and push them to the shared branch, and stop. Report "examples wait on the user's approval". No page opens from a subagent.
4. Approved examples: start the `do` skill on the ticket with the Skill tool, steps 1 to 5: do is the build, and its pull request body carries an `Examples:` line. The ticket is the request. Review (`do` step 6) waits for the user's merge pass.
5. Settle the tickets with `make-it-so`'s [SETTLE.md](../make-it-so/SETTLE.md). Stop at the draft: `make-it-so` is the user's call.
Report: the pull request link, its Check these list, the mutation counts from `do`'s sentinels pass, and anything you skipped.
```

The spark-joy run gets the same brief with `spark-joy` in place of `do`: no ticket to claim, its own step 2 replaced by the shared-branch line above, and its draft pull request replaced by a commit and push to the shared branch.
