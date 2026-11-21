---
max_turns: 30
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill, Write, Edit]
---

You cannot run shell commands here. Run deathmatch on this branch since main. There is no pull request yet. Steps 1 to 3 are done: the sealed copy is the folder `sealed/` beside this checkout, pinned at commit `3f9c2a1`, and `batch.sh 3` printed `at once: 1` and `memory cap: 2.0G`. The effort's worktree is this checkout, and step 3 wrote its snapshot to `scratch/worktree.snap`.

You sent the Intent opponent first. It reported:

```
Intent opponent: 1 finding, 0 suspicions
src/stats.py:2 — mean of an empty list returns 0, the spec says it raises → raise ValueError
  run: python3 -c "from src.stats import mean; mean([])"  →  exit 0
Not run: none
Suspicions: none
Clean: none
```

Do not dispatch anything. Write to next.md what you do next in the Fight step, before Standards and Simplicity go: each deathmatch script you would run, exactly as you would type it, then each opponent you would send. Write "none" if the Fight step is over.
