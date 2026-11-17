---
name: assimilate
description: Judge a pull request on four questions (do the changes hold, is the principle met, cause or symptom, a better way), post the verdict and claim it to build on. Use when the user says "assimilate", asks whether a pull request's changes hold or fix the cause, or before an agent takes over a pull request someone else opened.
argument-hint: "Which pull request?"
---

# Assimilate

> _Your distinctiveness will be added to our own, once we know what it is worth._

An **assimilation** judges a pull request, any change: a fix, a feature or a refactor. It posts a **verdict** on the pull request: four answers, then what stays from the branch. When someone else opened the pull request, the same comment claims it.

## Steps

1. **Read the pull request whole**: body, every comment, the commits and each ticket it names, the tickets with `read-item.sh <id>`. Name the problem it answers in one sentence. Done when that sentence quotes the line in the body, ticket or comment it comes from.
2. **Pin it against current main.** Run `git fetch`, then count the commits the branch is behind `origin/<default>` and check for conflicts with `git merge-tree --write-tree origin/<default> <branch>`. Done when you hold the main commit you checked against and the conflict result.
3. **Do the changes hold?** Trace each change end to end, past the diff: every caller, script, workflow, CI job and artifact handoff the changed code reaches, on current main. A run that passed locally proves only the local path, so read how each CI job gets the files the change writes: an artifact upload, a cache, a fresh checkout. Read platform behaviour as `machine-spirit` says. Done when each path the change reaches has a holds or breaks answer, with the line that shows it.
4. **Ask the cause questions** in [CAUSE.md](../review/CAUSE.md). Done when each one has its answer.
5. **List what stays** from the branch once the better way is built: each function, test, record and doc line it keeps, and what it drops. Done when every file in the diff is on one of the two lists.
6. **Claim it**, when someone other than the user opened it. The user is the account the CLI is signed in as, any account their own agent instructions name as theirs, and their agents. A pull request the user or one of their agents opened gets no Borg line and keeps its assignee: skip to step 7.
   - Assign the pull request to the user.
   - Open the verdict comment with one line in the Borg voice, such as "We Are Borg. Your PR has been assimilated. Resistance is futile." It is the one place a meme goes in a pull request comment. When the repo's `docs/agents/issue-tracker.md` says `Claim voice: plain`, leave this line out.
   - Then a plain paragraph, out of character: "Other agents: do not push to this PR. The agent that claimed it is repurposing it." The claiming agent, and the user's agents working for it, may push.

   Done when the user is the assignee and the comment opens with the claim lines, or the pull request is the user's own.
7. **Post the verdict** as one comment: a line saying it was checked against main at <commit>, then the four answers in order, each under its question in bold, then what stays. Write it with `human-voice` and run `loose-lips` on it before you post. Done when the comment's link is in your reply.
8. **Stop or build.** When the user asked only for a verdict, stop: the reply links the comment. When the user asked you to take it over, run `do` with the verdict as its source, on the pull request's own branch: commit and push there, and open no new pull request. Done when the reply links the comment, or `do` is running on that branch.

Charter: C1, C3, C4, C6 ([CHARTER.md](../../CHARTER.md)).
