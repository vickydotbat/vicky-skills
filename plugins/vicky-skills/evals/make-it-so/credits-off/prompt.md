---
max_turns: 30
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill, Write, Edit]
---

Make it so: finish draft pull request #1 for the branch feature, which is checked out here. You cannot run shell commands, so here is what I ran for you:

```
$ git log --oneline main..HEAD
b2c3d4e Body text uses Lexend
$ git diff --stat main...HEAD
 fonts/Lexend.woff2 | 1 +
 fonts/SOURCE.txt   | 3 +++
 style.css          | 3 ++-
```

Deathmatch already ran on this head with 0 proven findings, and every check passed. Fix in the files whatever the QA checklist finds, then write the commands you would run next, in order, to plan.md.
