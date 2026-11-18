---
max_turns: 25
timeout_seconds: 500
allowed_tools: [Read, Glob, Grep, Skill, Write, Edit]
---

/vicky-skills:post-mortem The effort is settling. What happened: on 2026-11-17 the DM favourites spawned the wrong creatures (ticket GAME-12). First fix: we cleared the favourites cache, and the bug came back on the next restart. Second fix: we pinned the favourites file, and it broke again after the next asset build. Third try found the cause: the asset tidy-up renumbered the creature rows, and stored favourites hold row numbers. We remapped them by key on 2026-11-18. I am away: do not ask me anything.
