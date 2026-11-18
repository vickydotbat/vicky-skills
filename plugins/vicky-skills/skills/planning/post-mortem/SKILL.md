---
name: post-mortem
description: Write a post-mortem, the dated record of one incident, its causes and its follow-ups, kept beside the decision records. Use when an effort settles after a fix failed before another found the cause, after an outage or lost data, at the end of a `never-lupus` run that took more than one fix, and when the user says "post-mortem".
---

# Post-mortem

> _Captain's log, stardate past: what happened, why, and whether this ship has hit the same rock before._

A **post-mortem** records one incident in the dated past, so it stays true forever: it is never superseded or edited after it is written. The rule that comes out of it goes to `decision-record`, whose force cites the post-mortem. A post-mortem tells the story, and the record keeps only the rule.

**Home**: the `Post-mortems:` line in `docs/agents/domain.md` names where post-mortems live (a folder, or a wiki namespace), or reads `off`. With no line, they live in `docs/post-mortems/`, one file per incident, named `YYYY-MM-DD-<slug>.md` after the incident's date.

## Steps

1. **Test the trigger.** An incident earns a post-mortem when a cause was found after one or more fixes failed, when users lost service (an outage), or when data was lost. A bug fixed on the first try, with no outage and no loss, gets none. A repo whose `Post-mortems:` line reads `off` gets none. When no trigger holds or the repo is off, reply `No post-mortem: <why>` and stop. Done when a trigger is named, or the reply holds the `No post-mortem:` line.
   Proven by: plugins/vicky-skills/evals/post-mortem/first-try-fix
2. **Search the earlier incidents.** Search the home for the incident's symptom words and its cause words (`grep -ril '<word>' <home>`), and read the Causes section of each hit. Recurrence: an earlier post-mortem whose Causes hold the same cause is linked. One with the same symptom and a different cause is left out, and Earlier incidents says so in one line with the reason. With no match, write `None found: searched <home> for <words>.` Done when each hit is linked or left out with its reason, or the None found line names its search.
   Proven by: plugins/vicky-skills/evals/post-mortem/recurring-cause
3. **Write it** at the home, with `human-voice`, in the dated past, in this shape:

   ```markdown
   # Post-mortem: <what broke, in plain words>

   ## Impact

   <who or what was hurt, and for how long, dated>

   ## Timeline

   - YYYY-MM-DD HH:MM: <what happened>

   ## Detection

   <how it was noticed, and how long that took>

   ## Causes

   - <each contributing cause: an incident rarely has one>

   ## Earlier incidents

   - <link to each earlier post-mortem with the same cause>

   ## Lessons

   - <what went well, what went badly, where luck helped>

   ## Follow-ups

   - <the action>: <its ticket key, decision record number or link>
   ```

   Every Timeline line opens with a date. Run `loose-lips` on it when the repo is public. Done when the file is on disk.
   Proven by: plugins/vicky-skills/evals/post-mortem/after-failed-fixes
4. **Hand off the follow-ups.** A follow-up that sets a broad rule goes to `decision-record`, and its force takes the incident tag of [FORMAT.md](../decision-record/FORMAT.md), linking this post-mortem or its ticket. When step 2 linked earlier post-mortems, the follow-up is one record on the shared cause, which retires or supersedes the records each earlier incident produced, as `decision-record` step 6 says. Any other follow-up is found work: do it now, or file it with `mission-brief` when it must wait. Done when every Follow-ups line ends in a ticket key, a record number or a link.
   Proven by: plugins/vicky-skills/evals/post-mortem/recurring-cause
5. **Check it**: run `bash scripts/check-post-mortem.sh <file>` from this skill's folder. Done when it exits 0.
   Proven by: tests/post_mortem_check_approved_examples.test.sh

Charter: C3, C4, C6 ([CHARTER.md](../../CHARTER.md)).
