---
name: spark-joy
description: Deepen one shallow module in a repo's busiest code and open a draft pull request, with behaviour held by the tests at its seam. Use when the user says "spark joy", "deepen" or "tidy the architecture", and when the session-start hook asks for a run.
---

# Spark joy

> _Does it spark joy? A module stays only if deleting it would spread its mess into its callers._

A **shallow module** fails the deletion test in [PRINCIPLES.md](../review/PRINCIPLES.md): its interface is nearly as big as its body, or it only passes calls through. A run folds one shallow module into its caller or the module it wraps, and changes no behaviour. The busiest code goes first, because that's where the next change lands.

A spark-joy run is the repo's health check: `do` aims for code that never needs one, and this catches what slipped. The hook's run comes from the plugin setting `${user_config.deepen_every_days}`. With `gamma_shift` at `engage`, the run joins `gamma-shift`'s queue as its last build. Otherwise it runs alone in one background subagent with `isolation: "worktree"`, so the user's first request is served alongside it.

## Steps

1. **Pick one module.** List the files changed most in recent history: `git log --since="30 days ago" --name-only --format= | sort | uniq -c | sort -rn | head -20`. Run the `simplicity-reviewer` agent with the repo as its scope, and keep its `shallow:` findings. Take the first finding in the busiest file. Skip any that a decision record settled. Done when one module and the module it folds into are named, or no finding is left: then report "Lean already" and stop.
2. **Branch** with `git fetch --prune`, then `git switch -c spark-joy-<module> origin/main`. Done when the branch exists.
3. **Hold the behaviour.** Find the tests at the highest seam that reaches the module, approved examples first. When no test reaches it, write tests at that seam that pass on `main` before you change anything. Done when the seam's tests pass with the module unchanged.
4. **Fold it in** with `do`'s smallest complete change, one caller at a time, the seam's tests green after each. A test marked `approved-spec` that has to change means the fold changes behaviour: undo it and stop with that reason. Done when the module is gone and every seam test passes.
5. **Mutate** the decision logic that moved, with `sentinels`. Done when no survivor is unanswered.
6. **Open a draft pull request** with `ship-it`. Its body names the module, why it failed the deletion test, where it went, and the net line count. Stop at the draft: `make-it-so` is the user's call. Done when the draft is open.
