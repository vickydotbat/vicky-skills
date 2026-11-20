---
name: engrave
description: Engrave a lesson: turn a snag, mistake or correction into a law in its repo. Use when the user says "codify", "lesson", "for the future", "from now on", "make sure we know" or "prevent this", when a fixed snag cost a retry or hit a platform limit, unasked after a serious mistake of your own, and for each finding settling or `captains-log` hands over. Any other correction waits for that settling.
---

# Engrave

> _So let it be written, so let it be done. A lesson leaves as a law, never as a promise._

A **snag** is one thing that went wrong: a red check, a crash, a retry, a wrong claim, or a correction from the user. A correction that cost no retry is engraved in the batch `make-it-so`'s SETTLE.md runs, not on the spot. A **serious snag** is one that spent money or credits nobody approved, lost, overwrote or deleted data, put a leak in text that left the machine, broke shared state (a pushed branch, a ticket, a service someone uses), or ran a script or command unread. Engrave a serious snag on the spot, unasked, in the turn you catch it. Stop the damage first, then engrave it, and tell the user both. No hook can judge serious, so this line and the description's trigger hold it, and `promise-guard` sends back a reply that promises to do better instead. A **law** is what stops the snag next time. An apology or "I'll remember" is no law: the next session never reads it.

Build every law for the next agent: it sees only the files it opened, copies the nearest example, and takes the shortest path that passes.

## Steps

1. **Name the snag** in one line: what happened, and what should have happened. A law that states how something behaves (a file format, a render, an engine rule) waits for the check that proves it: a fix only a live client can confirm is engraved after the user reports it working, never on the theory. Done when the line names a visible event, not a feeling.
2. **Pick the law** at the highest rung that holds it. First find out whether the snag is a **repeat**: look it up in the ledger, `bash ${CLAUDE_PLUGIN_ROOT}/scripts/lesson-ledger.sh since 2000-01-01T00:00:00Z`, and grep the skills, agent files and tests where the lesson would land for a rule that already covers it. A match means the rule exists and nothing made the agent follow it. A first-time snag becomes one line in the skill or agent file it belongs to, placed in the step the agent is in when the snag happens. A repeat is promoted. A wrong claim made from memory or a glance, and a rule the user asks to enforce, are promoted the first time. A promoted snag climbs this ladder, top first:
   1. **Remove the way to make it.** One owner per piece of state, one supported way per task, the old way and its dead examples deleted, a hand-synced list replaced by its source.
   2. **Guard it.** Build a check or a hook where one can hold the rule, and a skill line only where neither can, with the reason (`robot-voice` step 1). A check's error names the fix: the file, command or skill to use instead. Where the bad pattern is already common, the check fails only on a change that adds more.
   3. **A skill line**, with an example of the snag beside it.

   Done when you can say "first time" or "repeat of <entry or `file:line`>" and the snag has its law.
3. **Route it.** A home the user names wins. Otherwise sort each part with the **swap test**: retell the snag with this repo's own names (its languages, tools, build, CI, tracker, services, paths, conventions) swapped for another repo's. A part that still happens is a **plugin gap**. A part that goes away is a **repo gap**. A part with both splits in two: the plugin takes the rule and reads the repo's value from a `docs/agents/` line, and the repo takes the value. The plugin's own repo is a repo too: a gap in its tests or fixtures is a repo gap there. Then send each part to its home:
   - **A plugin gap** goes to the plugin's repo, when the user can push to it: `gh repo view <repository in plugin.json> --json viewerPermission` says `ADMIN`, `MAINTAIN` or `WRITE`. Hand it to an idle session in the plugin's repo (`ListAgents`, then `SendMessage`), else build it on a fresh branch from its main in a worktree, without asking. Never switch a checkout another session uses. When the repo is not pushable, or `gh` can't answer, it goes to the user's own agent setup: their `CLAUDE.md` (`~/.claude/CLAUDE.md`), or the repo that declares it when their setup lives in one.
   - **A repo gap** goes to the repo you work in, in a test, a standard or its agent docs, on the current effort's branch.

   In the ledger (step 5), a plugin gap is `plugin`, or `setup` where it went to the user's agent file, and a repo gap is `repo`.

   Done when each part is labelled `plugin gap` or `repo gap` and has one destination.
   Proven by: plugins/vicky-skills/evals/engrave/gap-swap-test
4. **Retire the old rule.** When the law replaces or reverses a rule written anywhere (a doc, a skill, a decision record, a ticket), run `plot-twist` with the old rule as the decision it replaces. When a structural law (rung 1 or 2) now holds what a written line said, delete that line, or cut it to a pointer at the check. Done when `plot-twist` has reported and no line restates a rule a check now holds, or the law replaces no written rule.
5. **Build and prove it** this turn, under the destination's own rules: test first where it is code, its checks run. Replay the real snag against the law: the check or hook goes red on the snag's own input (the command, the diff, the text) and on each sibling input of the same kind, and green once it is fixed. An exception the law must allow sits on its own line, with its reason. When you commit the rule, the commit message ends with `Engraved: <snag>`, and you run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/lesson-ledger.sh add <plugin|setup|repo> "<snag>"`, so `sup` counts it from any repo. A law that lands in a skill, in a repo with an `evals/` suite, also gets an eval case in the same commit: `evals/<skill>/<case>/`, with a prompt that recreates the snag and a free grader (regex, tool_used, tool_order, file_exists) that fails against the skill text from before the law. Name the case at the end of the ledger snag: `"<snag> (eval case: <skill>/<case>)"`. Every law names its proof: an eval case, a check or a hook. Write the law so the line after it reads `Proven by: <check>`, a repo-relative path to the test, the hook's test or the eval case folder, so `law-lint.sh` finds it. A law that is a hook or a check: its own test is its proof, and nothing more is added. A law routed to another repo or session names the proof in that destination. When you can name no proof, such as a skill line in a repo with no `evals/` and no check that can hold it, stop and tell the user the law is only a wish: engrave never names an eval case path that does not exist. Done when the law is committed and went red on the snag, with its eval case when it lands in a skill, handed to a session that accepted it, or filed with what it waits on.
   Proven by: plugins/vicky-skills/evals/engrave/law-names-proof
6. **Report** in one line per snag, in the reply that closes it:

   ```markdown
   📓 Engraved: <snag> → <law> in `<file>`
   ```

   A law whose proof is not built yet, such as one handed to another session, reports as `📓 Unproven: <snag> → <law>, waits on <proof>`, never as engraved.

   Add the rung and, for a promoted snag below rung 1, the reason in a few words the rung above it couldn't hold it. Done when every snag of the turn has its line.
   Proven by: plugins/vicky-skills/evals/engrave/law-names-proof

Charter: C5, C6 ([CHARTER.md](../../CHARTER.md)).
