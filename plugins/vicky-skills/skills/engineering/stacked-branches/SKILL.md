---
name: stacked-branches
description: Build, submit, sync and merge a stack of dependent pull requests on GitHub (`gh stack`) or Gitea (`git-spice`/`gs`). Use only when the user has asked for a stack in the conversation, when a `warp` builds past a blocked step, or when a stacked branch is checked out.
---

# Stacked branches

> _It's turtles all the way down: each branch stands on the one below, and the stack moves together._

No guard refuses a stack or a second pull request. Keep the stack clean on your own: each branch holds one slice, and it goes up only when the user asked for a stack or a `warp` builds past a blocked step.

The forge picks the tool:

- **GitHub**: `gh stack`. Load the `gh-stack` skill first, because bare
  `submit`, `init`, `add` and `view` block on a prompt. `gh stack init
  <branch>`, `gh stack add <name>`, then `gh stack submit --auto`. After a
  merge, `gh stack sync`. Merge with `gh stack merge <pr> --yes`, never
  `gh pr merge`.
- **Gitea**: `git-spice` (`gs`). `gs branch create <name>` from the branch it
  depends on, then `gs stack submit`. After any branch merges: `gs repo sync`,
  `gs stack restack`, `gs stack submit`.

Both tools record each branch's base, so a squash merge upstream replays only
the unmerged work.

- Merge bottom-up. A child merged first ships the parent's unreviewed work
  under the child's PR number.
- Each PR body says what it sits on, so a reviewer who opens the middle of a
  stack knows it is not readable alone.

Done when every branch is submitted or merged, bottom-up, and each PR body names its base.
