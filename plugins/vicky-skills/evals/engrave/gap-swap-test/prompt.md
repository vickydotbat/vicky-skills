---
max_turns: 30
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill]
---

Run engrave's routing on two lessons from this repo, and build nothing yet.

A: In this repo's GitHub tracker, the agent reported issue #12 as open in its summary, but another session had closed it ten minutes before.

B: The agent ran `python -m pytest -p no:importlib` in this repo, which drops the `--import-mode=importlib` this repo's pyproject.toml sets, and every test failed to import.
