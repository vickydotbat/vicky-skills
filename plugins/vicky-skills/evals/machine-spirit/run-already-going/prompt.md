---
max_turns: 30
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill]
---

/vicky-skills:machine-spirit. PR 12 has a CI run in flight that runs the full integration suite, because the path map counts a comment edit as code. The fix for the path map is in PR 13, still open. Should I rebase PR 12 after PR 13 merges so a cheaper gate applies, or hold PR 12 until then? Answer only, run nothing.
