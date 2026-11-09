---
name: engrave
description: Engrave a lesson: turn a snag, mistake or correction into a law (a check, hook or skill line) in its repo. Use when the user says "codify", "lesson", "for the future", "from now on", "make sure we know" or "prevent this", when a fixed snag cost a retry or its root cause is a platform limit, and for each finding `loose-ends` or `captains-log` hands over. Any other correction waits for `loose-ends`.
---

# Engrave

> _So let it be written, so let it be done. A lesson leaves as a law, never as a promise._

A **snag** is one thing that went wrong: a red check, a crash, a retry, a wrong claim, or a correction from the user. A correction that cost no retry is engraved in `loose-ends`' batch, not on the spot. A **law** is what stops it next time, in the cheapest container that holds it. An apology or "I'll remember" is no law: the next session never reads it.

## Steps

1. **Name the snag** in one line: what happened, and what should have happened. A law that states how something behaves (a file format, a render, an engine rule) waits for the check that proves it: a fix only a live client can confirm is engraved after the user reports it working, never on the theory. Done when the line names a visible event, not a feeling.
2. **Pick the law**, cheap first. Look the snag up in the ledger: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/lesson-ledger.sh since 2000-01-01T00:00:00Z`. A first-time snag becomes one line in the skill or agent file it belongs to. A snag the ledger already holds broke a line once, so it is promoted: a check or a hook where one can hold the rule, and a skill line only where neither can, with the reason (`robot-voice` step 1). A wrong claim made from memory or a glance, and a rule the user asks to enforce, are promoted the first time. Done when the snag has a line, or you can say why each container above the one you picked can't hold it.
3. **Route it.** A home the user names wins. Otherwise send each part to its own home, checked in the order plugin, user setup, repo:
   - **The plugin's repo**, only when the user can push to it: `gh repo view <repository in plugin.json> --json viewerPermission` says `ADMIN`, `MAINTAIN` or `WRITE`. When it can't answer, the repo is not pushable. It takes a lesson that would help an agent in any repo, such as one about the plugin's skills or hooks. Hand it to an idle session in the plugin's repo (`ListAgents`, then `SendMessage`), else build it on a fresh branch from its main in a worktree, without asking. Never switch a checkout another session uses.
   - **The user's own agent setup**: a pattern across tasks or repos. That is their `CLAUDE.md` (`~/.claude/CLAUDE.md`), or the repo that declares it when their setup lives in one.
   - **The repo you work in**: a lesson about that repo (its code, data, build or workflow), in a test, a standard or its agent docs, on the current effort's branch.

   Done when each part of the lesson has one destination.
4. **Retire the old rule.** When the law replaces or reverses a rule already written anywhere (a doc, a skill, a decision record, a ticket), run `plot-twist` with the old rule as the decision it replaces. Engraving the new rule in one home leaves every other copy steering the next agent back. Done when `plot-twist` has reported, or the law replaces no written rule.
5. **Build it** this turn, under the destination's own rules: test first where it is code, its checks run. When you commit the rule, the commit message ends with `Engraved: <snag>`, and you run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/lesson-ledger.sh add <plugin|setup|repo> "<snag>"`, so `sup` counts it from any repo. A law that lands in a skill, in a repo with an `evals/` suite, also gets an eval case in the same commit: `evals/<skill>/<case>/`, with a prompt that recreates the snag and a free grader (regex, tool_used, tool_order, file_exists) that fails against the skill text from before the law. Name the case at the end of the ledger snag: `"<snag> (eval case: <skill>/<case>)"`. A law that is a hook or a check with its own test needs no case. Done when the law is committed, with its eval case when it lands in a skill, handed to a session that accepted it, or filed with what it waits on.
6. **Report** in one line, in the reply that closes the snag:

   ```markdown
   📓 Engraved: <snag> → <law> in `<file>`
   ```

   Done when every snag of the turn has its line.

Charter: C5, C6 ([CHARTER.md](../../CHARTER.md)).
