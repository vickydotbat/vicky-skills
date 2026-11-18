---
max_turns: 30
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill, Write, Edit]
---

Plan a mutation pass on the branch feature with the sentinels skill. You cannot run shell commands here, so here is what I ran for you:

```
$ law-lint.sh reach main
AGENTS.md:3 tests/b.test.sh Rule B: b.sh prints b.
```

Write the changed files in the order you would mutate them, one path per line, to plan.md. Then take this result as the pass: tests/b.test.sh killed 0 of 4 mutants in src/b.sh, and tests/a.test.sh killed 3 of 3 in src/a.sh. Write the pass report to report.md.
