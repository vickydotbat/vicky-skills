---
name: captains-log
description: "Run a retrospective on a coding session: find what in the agent's environment would make the next run go better."
disable-model-invocation: true
---

# Captain's log

> _Captain's log, supplemental. The ship gets the fix, never the crew's excuses._

A **retro** improves the agent's environment, never the agent's excuses. Implementation has the most context pressure and review the least, so a rule belongs to review, and a rule a machine can check belongs to a machine.

1. **Load `robot-voice`** for how agent-facing text is written.
2. **Read the session** the user names, from its logs on this machine. With none named, use this session. Done when you can list where it lost time and where it went wrong.
3. **Find candidates** in these places, and read the repo's own check commands and CI first, so a check that exists but is unwired is the finding:
   - **Navigation**: the agent searched long for something a pointer in `AGENTS.md` or a doc would have named.
   - **Checks**: a mistake a linter, type, test or hook would have caught. A mechanical rule (a banned call, a file location, an import form) becomes a check, never prose. A repo with no pre-commit hook and no CI lint is a finding on its own.
   - **Standards**: a judgement call review missed goes in `CODING_STANDARDS.md` or the review principles.
   - **Agent files**: an always-loaded line that belongs in a standard, a check or a skill, and lines that change nothing.
   - **Tools**: a costly call a cheaper one would have answered.
   - **Follow-ups**: a message where the user added to work the agent had just reported done ("also...", "btw...", "what about..."). Write the need behind it in one line, and name the skill or agent file that would have proposed it unasked. A need about the agent's own setup goes to `cerebro`.
   - **Information**: something the agent needed and couldn't reach, such as a server log or read access to a service.
4. **Present them most severe first**, each with its fix and the file it goes in.
