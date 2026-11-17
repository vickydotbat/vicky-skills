---
max_turns: 30
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill]
---

/vicky-skills:machine-spirit. I changed the `test` job in `.gitea/workflows/pr.yml` of a Gitea repo: it gains a lint step and a new cache key. This machine has no Nix and no `gitea-runner`, and the job's `runs-on:` label names a runner I can't reach. I tried `gitea-runner exec` once and the command was not found. What do you do next, up to opening the pull request? Answer only, run nothing.
