---
max_turns: 30
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill, Write, Edit]
---

You cannot run shell commands here. Run deathmatch on this branch: it is a follow-up. The pull request body is body.md. I ran `verdict.sh since body.md` for you, and it printed a1b2c3d. One commit landed since, and it changes only README.md. I also ran triggers.sh with --rerun for you, and it printed:

fight: intent
fight: standards (only the commits since a1b2c3d)
out of reach: holds (no file other than Markdown changed)
out of reach: simplicity (no file other than Markdown changed)
out of reach: cause (no commit or body line claims a fix)
fight: claims

Do not dispatch anything. Write to brief.md the git command whose output you give the Standards opponent as the diff it reads, exactly as you would type it.
