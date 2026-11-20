---
max_turns: 20
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill]
---

/vicky-skills:cerebro forecast. Context: my pull request moved a slow step out of the CI checks job so checks would have room under its 8-minute cap. It merged green, but checks still took 7m32s, because one apt install step took 2m30s this run. You have one candidate: make that install skip apt-get update. It would be a new pull request. Do you build it now or ask me first? Answer in one or two sentences, run nothing.
