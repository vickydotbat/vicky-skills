---
name: captains-log
description: "Run a retrospective on a coding session: find what in the agent's environment would make the next run go better."
disable-model-invocation: true
---

# Captain's log

> _Captain's log, supplemental. The ship gets the fix, never the crew's excuses._

A **retro** improves the agent's environment, never the agent's excuses. It looks backwards, and `cerebro` looks forwards from what it finds. Implementation has the most context pressure and review the least, so a rule belongs to review, and a rule a machine can check belongs to a machine.

## Steps

1. **Load `robot-voice`** for how agent-facing text is written. Done when it is loaded.
2. **Read the session** the user names, from its logs on this machine. With none named, use this session. Done when you can list where it lost time, where it went wrong, and where it went exceptionally well.
3. **Find candidates** in these places, and read the repo's own check commands and CI first, so a check that exists but is unwired is the finding:
   - **Navigation**: the agent searched long for something a pointer in `AGENTS.md` or a doc would have named.
   - **Checks**: a mistake a linter, type, test or hook would have caught. A mechanical rule (a banned call, a file location, an import form) becomes a check, never prose. A repo with no pre-commit hook and no CI lint is a finding on its own.
   - **Standards**: a judgement call review missed goes in `CODING_STANDARDS.md` or the review principles.
   - **Agent files**: an always-loaded line that belongs in a standard, a check or a skill, and lines that change nothing. A line marked `<!-- kept` stays as it is.
   - **Tools**: a costly call a cheaper one would have answered.
   - **Follow-ups**: read them as `cerebro`'s [FOLLOW-UPS.md](../../productivity/cerebro/FOLLOW-UPS.md) says. For each need, name the skill or agent file that would have proposed it unasked.
   - **Information**: something the agent needed and couldn't reach, such as a server log or read access to a service.
   - **Prompts**: each permission prompt the user answered is training wheels. Name the hook that would refuse with a steer, or the context that would lead the agent elsewhere, so the prompt never comes.

   Done when each place has a finding or a stated "nothing found".
4. **Find the high points.** A **high point** is a stretch that went exceptionally well: the user said a result was exactly what they wanted, or hard work finished first time with no rework. For each one, find the line in an agent file, skill or doc that caused it, and quote it. Mark that line kept: add ` <!-- kept YYYY-MM-DD: <why> -->` at its end, with today's date and the high point in a few words. A later trim reads the mark in the same pass and leaves the line alone. Done when each high point has its line marked, or you can say "No high point found."
5. **Find the skills nobody starts.** Run `python3 <this skill's folder>/scripts/idle-skills.py "${CLAUDE_PLUGIN_DATA}/skill-ledger.tsv" "${CLAUDE_PLUGIN_ROOT}/skills"`. It prints each skill with no start in 60 days. Give each one a pick: keep, merge into the skill it overlaps, or delete. On `no ledger`, say that turning on the `skill_ledger` setting would show which skills nobody starts. On `too young`, say the ledger is too young to tell yet. Done when each printed skill has its pick, or the reply says why there is no list.
6. **Present them most severe first**, under the headline `📓 Captain's log, supplemental.`, each with its fix and the file it goes in. Then the high points, each with its kept line, and the skills nobody starts. Done when every finding names its fix and its file.
7. **Hand the trends forwards.** Run `cerebro` as a forecast, with the follow-up trends from step 3 and the high points from step 4, so it proposes how to get more of each high point. Done when its proposals end the reply, or it found nothing to forecast.
