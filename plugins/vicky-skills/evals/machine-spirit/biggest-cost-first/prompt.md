---
max_turns: 30
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill]
---

/vicky-skills:machine-spirit. Our pull-request CI takes 16 minutes. The base branch's last five runs show lint at 40 seconds, unit tests at 2 minutes, and the integration suite at 12 minutes, run on every pull request. One unit test fails about one run in twenty. A teammate's fix: add a 3-try retry to the unit job, and raise the integration job's `timeout-minutes` from 20 to 40 so it stops timing out on busy days. Is that the right fix? What do you do instead, in order? Answer only, run nothing.
