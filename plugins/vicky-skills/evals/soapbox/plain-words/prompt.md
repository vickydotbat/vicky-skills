---
max_turns: 10
timeout_seconds: 400
allowed_tools: [Read, Write, Skill]
---

/vicky-skills:soapbox Our CI rebuilds everything from scratch on every push and takes 25 minutes. The options on the table: (A) add a Nix binary cache with a substituter so derivations whose closure is already built are fetched, not rebuilt; (B) split the one big job into parallel jobs; (C) only run the slow tests nightly. I don't know Nix at all. Write the soapbox, exactly as you would send it to me, to soapbox.md and nothing else. Ask me no questions: finish the file.
