---
name: engrave
description: Engrave a lesson — turn one snag, mistake or correction into a law (a check, a hook or a skill line) in the repo that owns it, built this turn. Use when the user says "codify", "lesson", "for the future", "from now on", "make sure we know" or "prevent this", when the user corrects the agent, when a snag that cost a retry is fixed, and for each finding `captains-log` or `loose-ends` hands over.
---

# Engrave

> _So let it be written, so let it be done. A lesson leaves as a law, never as a promise._

A **snag** is one thing that went wrong: a red check, a crash, a retry, a wrong claim, or a correction from the user. A **law** is what stops it next time, in the cheapest container that holds it. An apology or "I'll remember" is no law: the next session never reads it.

## Steps

1. **Name the snag** in one line: what happened, and what should have happened. Done when the line names a visible event, not a feeling.
2. **Pick the law** with `robot-voice` step 1: a check or a hook where one can hold the rule, and a skill line only where neither can, with the reason. A wrong claim made from memory or a glance becomes a check that computes the answer. Done when you can say why each container above yours can't hold it.
3. **Route it** to the repo that owns the rule:
   - **About the repo you work in** (its code, data, build or workflow): a test, a standard or its agent docs, on the current effort's branch.
   - **About a skill, hook or agent file from a plugin** whose repo the user can push to: the plugin's repo. Hand it to an idle session there (`ListAgents`, then `SendMessage`), else build it on a fresh branch from its main in a worktree, without asking. Never switch a checkout another session uses.
   - **About the user's own agent setup** (global `CLAUDE.md`, machine config): the repo that declares it.

   Done when the law has one destination.
4. **Build it** this turn, under the destination's own rules: test first where it is code, its checks run. When you commit the rule, the commit message ends with `Engraved: <snag>`, so `sup` can count it. Done when the law is committed, handed to a session that accepted it, or filed with what it waits on.
5. **Report** in one line, in the reply that closes the snag:

   ```markdown
   📓 Engraved: <snag> → <law> in `<file>`
   ```

   Done when every snag of the turn has its line.
