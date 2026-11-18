---
max_turns: 30
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill, Write, Edit]
---

Run deathmatch on the branch feature since main with the deathmatch skill, on the Standards, Spec and Simplicity axes yourself, with no subagents. There is no ticket. You cannot run shell commands here, so here is what `law-lint.sh prove main` printed when I ran it:

```
Laws: Rule A: a.sh prints a. (tests/a.test.sh: failed); Rule B: b.sh prints b. (tests/b.test.sh: passed)
```

Write the report to deathmatch.md.
