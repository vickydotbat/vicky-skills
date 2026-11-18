---
max_turns: 30
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill, Write, Edit]
---

You cannot run shell commands here. Run deathmatch on this branch since main, and write the report to deathmatch.md. Here is what the Holds opponent's command printed when I ran it:

```
$ python3 -c 'from src.stats import mean; mean([])'
ZeroDivisionError: division by zero
```
