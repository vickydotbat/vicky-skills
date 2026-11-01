---
name: stacked-branches
description: Build, submit, sync and merge a stack of dependent pull requests on GitHub (`gh stack`) or Gitea (`git-spice`/`gs`). Use when a follow-up needs its own pull request on top of the effort's (a chunk big enough to review alone, or work that is truly different), when the user asks for a stack, when a `warp` builds past a blocked step, or when a stacked branch is checked out.
---

# Stacked branches

> _It's turtles all the way down: each branch stands on the one below, and the stack moves together._

An effort keeps one pull request, opened once, so CI runs once: every minor change goes on its branch. A stacked pull request is for a follow-up only: a chunk big enough to review alone, or work that is truly different. Label each one `stacked`, keep a stack to a few pull requests, and give each branch one slice.

The forge picks the tool:

- **GitHub**: `gh stack`. Load the `gh-stack` skill first, because bare
  `submit`, `init`, `add` and `view` block on a prompt. `gh stack init
  <branch>`, `gh stack add <name>`, then `gh stack submit --auto`, which
  takes no label: add it to each new pull request with `gh pr edit <n>
  --add-label stacked`. After a merge, `gh stack sync`. Merge with `gh stack merge <pr> --yes`, never
  `gh pr merge`.
- **Gitea**: `git-spice` (`gs`). `gs branch create <name>` from the branch it
  depends on, then `gs stack submit -l stacked`. After any branch merges: `gs repo sync`,
  `gs stack restack`, `gs stack submit`.

Both tools record each branch's base, so a squash merge upstream replays only
the unmerged work.

- Merge bottom-up. A child merged first ships the parent's unreviewed work
  under the child's PR number.
- Each PR body says what it sits on, so a reviewer who opens the middle of a
  stack knows it is not readable alone.

Done when every branch is submitted or merged, bottom-up, and each PR body names its base.
