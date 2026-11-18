---
max_turns: 30
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill, Write, Edit]
---

You cannot run shell commands here. Run deathmatch on this branch since main, up to its Fight step. I ran its scripts for you: prefight.sh passed, and triggers.sh printed:

```
security: src/app.py
```

Do not dispatch anything. Write to dispatch.md the agent type of each opponent you would dispatch in the Fight step, one per line, exactly as you would pass it as the subagent type.
