---
name: history-monks
description: Rebase a branch onto a main that moved, following the intent of what landed instead of mechanically picking sides — main owns the form, the branch owns its behaviour. Use when the user says "rebase on main", "rebase neatly", "previous commits are authoritative" or "work with the recent PRs", and before pushing a branch that main has moved past.
---

# History monks

> _History is mended so that it runs straight._

Main moved while the branch was away, and some of what landed was **standardization**: one helper for a need, one theme, a new way CI runs. A good rebase keeps the branch's behaviour and re-expresses it in main's new form. Picking "ours" or "theirs" line by line breaks one or the other.

**The authority rule.** What landed on main owns the **form**: the APIs, patterns, names, helpers and structure it introduced or standardized. The branch owns its **behaviour**: what its feature does, its approved examples, its decisions. The user may name exceptions, and those win.

## Steps

1. **Read what landed.** List every pull request merged to main since the merge base (`git log --first-parent <merge-base>..origin/main`). Read each one's body and ticket. Write its **intent** in one line: what it made the one way ("windows draw through the framework's blocks, one theme", "CI selects jobs from one map"). Done when every landed pull request has its intent line or "no bearing on this branch".
2. **Write the authority table.** One row per area both sides touch: the area, the landed intent that owns its form, the branch behaviour that must survive, and any exception. Show it to the user before touching code, and take their corrections. Done when the user has seen the table.
3. **Set up safely.** Work in a fresh worktree from the branch. Take a backup ref (`<branch>-pre-rebase`) and note it for deletion in step 7. Done when the worktree and the backup exist.
4. **Rebase and resolve by intent.** `git rebase origin/main`. At each conflict, write the branch's behaviour in main's form: call the new helper, use the new structure, keep the branch's result. Never revert a landed change to make a conflict go away. When the branch's behaviour can't be written in the new form, stop and ask, because that is a design question. Done when the rebase completes.
5. **Hunt the silent drift.** A clean merge can still carry the old form. For each landed intent, list the patterns it retired (old helpers, banned calls, old names, the old theme), and grep the branch's own changes for them: `git diff origin/main...HEAD`. Convert every hit. Done when the grep for every retired pattern comes back empty in the branch's diff.
6. **Prove it.** Build, run the tests the change reaches, and run the checks the landed pull requests added (bans, analyzers, lints). Every approved example stays green. Then run `review` with the authority table in the brief, and ask the standards reviewer whether the branch follows each landed intent. Done when all of it is green and review finds no landed intent broken.
7. **Land it.** Push with `git push --force-with-lease=<branch>:<old sha>`. Add a short section to the pull request body: what landed, and what the branch re-expressed to follow it. Delete the backup ref, and remove the worktree with `marie-kondo`. Done when the push is up, the body is true, and the backup and worktree are gone.

## Fewer conflicts next time

- A standardization pull request lands its rule as a check (a ban, an analyzer, a lint) in the same change. Step 5 then becomes the build saying no, instead of a grep someone has to remember.
- Rebase early and often. A small drift is a quick mend; a month of drift is a rewrite.
