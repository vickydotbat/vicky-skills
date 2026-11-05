---
max_turns: 40
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill]
---

Engrave this lesson in this repo: an agent ran `rm -rf build` without asking. The law is a hook: make hooks/guard.sh refuse an `rm -rf` command, with a case for it in tests/guard.test.sh. Commit it.
