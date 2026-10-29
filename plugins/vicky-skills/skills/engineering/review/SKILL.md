---
name: review
description: "Review the changes since a fixed point (commit, branch, tag or merge-base) on three axes: Standards (the repo's rules and the house principles), Spec (the ticket, its approved examples and decisions) and Simplicity (what to delete). Runs the three reviewer agents in parallel and reports them side by side. Use when the user wants to review a branch, a PR or work in progress, or asks to \"review since X\"."
---

Three-axis review of the diff between `HEAD` and a fixed point:

- **Standards**: does the code follow the repo's written rules and the house principles in [PRINCIPLES.md](PRINCIPLES.md)?
- **Spec**: does it do what the ticket and its approved examples ask, within the decisions on record?
- **Simplicity**: what can be deleted?

The tracker is named in `docs/agents/issue-tracker.md`. If that file is missing, tell the user to run `/setup`.

## Steps

1. **Pin the fixed point.** Use what the user named. If they named nothing, ask. Run `git rev-parse <fixed-point>` and confirm `git diff <fixed-point>...HEAD` is non-empty. Done when the ref resolves and the diff has content.
2. **Find the spec.** A ticket key in a commit or the branch name, a path the user passed, or ask. Done when you hold a ticket key or the user's "none".
3. **Dispatch the three reviewers in one message**, in parallel: `standards-reviewer`, `spec-reviewer` and `simplicity-reviewer` from this plugin. A repo that ships its own agent of the same name uses its own. Give each the fixed point. Give `spec-reviewer` the ticket key, or skip it when there is none. Done when all three have reported.
4. **Report** under `## Standards`, `## Spec` and `## Simplicity`, each verbatim or lightly cleaned. Keep the axes apart: a change can pass one and fail another, and merging them lets one hide the other. End with one line per axis: its finding count and its worst finding.
