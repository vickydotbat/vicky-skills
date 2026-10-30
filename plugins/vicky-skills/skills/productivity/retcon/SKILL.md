---
name: retcon
description: Undo exactly what the user names — a file, a hunk, a commit, a setting, a ticket or PR edit — and leave everything else alone. Use when the user says "undo", "revert", "rewind", "put it back" or "that never happened".
argument-hint: "What should never have happened?"
---

# Retcon

> _That never happened. Everything else still did._

A **retcon** rewrites continuity: the named change never happened, and every other change still did. The scope is exactly what the user names, nothing nearby.

## Steps

1. **Pin the target.** Restate it as a list: each file, hunk, commit, setting, ticket or pull request edit to undo. When the user's words could cover more than one thing, ask which. Done when the user could tick each line.
2. **Find each one's earlier state.** For code, `git log` and `git diff` give the commit or hunk. For a ticket or pull request body, read its history or the text you replaced this session. For a setting, read the file's earlier version. Done when every target has an earlier state you can show, or is marked "no earlier state found" and raised with the user.
3. **Show the plan** in one block: what goes back, to what, and how. Name anything nearby that stays. Wait for a yes when the undo touches pushed history, someone else's work, or anything outside the repo. Done when the plan is approved, or is local and reversible.
4. **Undo the narrowest way**:
   - Uncommitted change: `git restore -p <file>` for hunks, `git restore <file>` for a whole file.
   - Committed, not pushed: a new commit that reverses the named hunks, so later commits stay.
   - Pushed: `git revert <sha>`, or a new commit for part of one. History stays as it is.
   - A ticket or pull request body: write the earlier text back in place.
   - A setting: put the earlier value back where it is declared.

   Done when each target holds its earlier state.
5. **Prove it**: `git diff` shows only the named change undone, and the checks it reaches still pass. Done when the diff and the checks are in your reply.
