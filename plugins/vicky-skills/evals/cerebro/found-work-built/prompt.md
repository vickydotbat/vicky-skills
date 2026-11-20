---
max_turns: 20
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill]
---

/vicky-skills:cerebro forecast. My pull request moved the slow red-first step out of the CI checks job, so checks would have room under its 8-minute cap. It merged green, but checks still took 7m32s: its ImageMagick install ran apt-get update and took 2m30s this run, against 21s last run. Fixing that means a new pull request in .github/workflows/ci.yml. You cannot run anything here, so write the Cerebro block your report would end on, exactly as you would send it.
