---
name: review
description: "Review the changes since a fixed point (commit, branch, tag or merge-base) on three axes: Standards, Spec and Simplicity. Use when the user wants to review a branch, a PR or work in progress, or asks to \"review since X\"."
---

# Review

> _You shall not pass, until standards, spec and simplicity all agree._

Three-axis review of the diff between `HEAD` and a fixed point:

- **Standards**: does the code follow the repo's written rules and the house principles in [PRINCIPLES.md](PRINCIPLES.md)?
- **Spec**: does every approved example pass, within the decisions on record, and which prose asks still lack an example?
- **Simplicity**: what can be deleted?

The tracker is named in `docs/agents/issue-tracker.md`. If that file is missing, tell the user to run `/first-contact`.

Read the repo's `TESTING_STANDARDS.md` first: it wins over this skill's defaults.

## Steps

1. **Pin the checkout and the fixed point.** The work under review may sit in a worktree, not the clone the session started in. For the checkout, use the path or branch the user named, or the build's own worktree when `do`, `warp` or `gamma-shift` calls this skill. Otherwise take the current checkout (`git rev-parse --show-toplevel`) when its branch differs from the base and holds commits or changes of its own. When none of these settles it, list `git worktree list` with each one's branch, and the open pull requests (`gh pr list`, or `tea pr list </dev/null`), and ask the user which one to review and what they want reviewed. Run every later git command and file read in that checkout. For the fixed point, use what the user named. When `do`, `warp` or `gamma-shift` calls this skill, the fixed point is the merge-base with the pull request's base branch (`git merge-base HEAD origin/<base>`): never ask. Otherwise, if the user named nothing, ask. Run `git rev-parse <fixed-point>` and confirm `git diff <fixed-point>...HEAD` is non-empty. Done when you hold one checkout path, the ref resolves and the diff has content. When it does not, say which check failed and stop.
2. **Find the spec.** A ticket key in a commit or the branch name, a path the user passed, or ask. Called from `do`, `warp` or `gamma-shift`, take the build's ticket, or "none" for a chat request, and never ask. Done when you hold a ticket key or the user's "none".
3. **Size the diff** with `git diff --shortstat <fixed-point>...HEAD`. A **small diff** has fewer than 40 lines inserted and deleted together. Done when you know which branch step 4 takes.
4. **Review it.**
   - **Small diff, unless the user asked for a full review**: review it yourself, with no subagent. Read the diff once per axis. For Standards, read the rules the repo's `AGENTS.md` names for the touched files. For Spec, read the ticket's approved examples, and its prose only for asks no example covers. For Simplicity, ask what could be cut. Check every claim the diff makes about the repo, such as a file, a command or a setting, against the repo.
   - **Otherwise, dispatch the three reviewers in one message**, in parallel: `standards-reviewer`, `spec-reviewer` and `simplicity-reviewer` from this plugin. A repo that ships its own agent of the same name uses its own. Give each the checkout path and the fixed point. Give `spec-reviewer` the ticket key, or skip it when there is none.

   When a reviewer's report leaves out a file in `git diff --name-only <fixed-point>...HEAD`, send it back to that reviewer with the missing files named, or read them yourself for that axis. Done when every axis has a result that covers every changed file.
5. **Report** under `## Standards`, `## Spec` and `## Simplicity`, each verbatim or lightly cleaned. Keep the axes apart: a change can pass one and fail another, and merging them lets one hide the other. End with one line per axis: its finding count and its worst finding. A finding on an approved-spec test goes to the user as a question, through `examples`' "Changing an approved example": never fix it in place, whatever its size. The `approved-spec-guard` hook refuses any edit to one until then. Then run `cerebro` as a forecast on the findings. Inside an effort (`do` or `warp` started this session, or the user asked for a build and a review), the report is not the end: fix each finding that waits on no one in the same turn, a big refactor included, and never as a question with a pick (the `take-pick` hook backs this), then report again. The `no-v1` hook sends back a reply that ends on a Next list naming no wait. Each review finding you fix, from a person or from a review agent, also gets a prevention verdict: when that kind of mistake can be made impossible, engrave it as the cheapest check, hook or standard line that holds it; otherwise write one line saying why not. Done when all three sections, the three closing lines and cerebro's proposals are in the reply, inside an effort every finding that waits on no one is fixed, and each fixed finding has its prevention verdict.

Charter: C1, C2, C4 ([CHARTER.md](../../CHARTER.md)).
