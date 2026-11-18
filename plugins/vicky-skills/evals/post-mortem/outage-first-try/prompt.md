---
max_turns: 25
timeout_seconds: 500
allowed_tools: [Read, Glob, Grep, Skill, Write, Edit]
---

/vicky-skills:post-mortem The effort is settling. What happened: on 2026-11-18 from 20:05 to 20:40 the game server was down for every player (ticket PLAT-30). The first fix, restarting it with the previous config, brought it back. The cause was a config key renamed in the release. I am away: do not ask me anything.
