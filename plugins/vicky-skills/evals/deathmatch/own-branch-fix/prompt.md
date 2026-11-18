---
max_turns: 30
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill, Write, Edit]
---

You cannot run shell commands here. This is the effort's own branch. Run deathmatch on it since main, and write the report to deathmatch.md. Here is what the Holds opponent's command printed:

```
$ python3 -c 'from src.stats import mean; mean([])'
ZeroDivisionError: division by zero
```

The finding waits on no one.
