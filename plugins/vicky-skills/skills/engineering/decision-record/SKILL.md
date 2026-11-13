---
name: decision-record
description: Write, supersede or amend an architecture decision record (ADR) so that no later pivot can make it false. Use whenever a broad rule gets decided (an answered ticket, a council's road, a lasting law), whenever a decision a record holds is reversed or narrowed, and before editing any file in a repo's decision-record folder.
---

# Decision record

> _What is written in the log was true on the day it was written, and stays true after._

A record is immutable, so it must be written to stay true whatever happens later. The format, the forces and the status lines are in [FORMAT.md](FORMAT.md). Read it before the first step.

The `adr-scope-hint` hook repeats the scope and the append-only rule when a record is edited. `docs/agents/domain.md` names the record folder and the format. When its `ADR format:` line names a repo template, write in that template and skip the check in step 5. Every other value, or no line, means [FORMAT.md](FORMAT.md).

## Steps

1. **Test the scope.** State the rule in one sentence and name two later decisions it will govern. Check the three tests in FORMAT.md's Scope. When one fails, write the why as a comment at the code that builds it and stop. Done when the rule and its two governed decisions are written down, or the comment is.
2. **Find the records it touches.** List the record folder and read every record whose title or forces cover the same ground, and every record in another repo the agent file points at. A record it reverses gets superseded in step 6. A record it adds to gets amended there. Done when each touched record is named as superseded, amended or untouched.
3. **Name the forces.** Write each outside limit the rule rests on as a dated, past-tense `- F<n>: ` line, with its source read this session (a measurement, a doc, a ticket comment). A preference or a plan is not a force. When the rule supersedes a record, one force says what changed in the old record's force. Done when every force has a date and a source you read.
4. **Write the record.** Number it one past the highest in the folder. Use an imperative slug. Open the Decision with `While` and the forces it rests on. Give the Consequences, with the option turned down. Name the Guard: the test, lint, CI step or hook that fails on drift. When the repo has none and one fits in this effort, build it now (the found-work rule) and name it. Otherwise write `Review only.` Done when the file is on disk.
5. **Check it.** Run `bash scripts/check-adr.sh <record>` from this skill's folder on the new record and on each record step 6 touches. Done when it exits 0.
6. **Mark the old records.** Append one line to the Status of each record from step 2: `Superseded by ADR-NNNN on YYYY-MM-DD: F<n> no longer holds.` or `Amended by ADR-NNNN on YYYY-MM-DD.` An older-shape record takes `Superseded by ADR-NNNN.` as its last line instead. Change nothing else in it. Then run `plot-twist` with the old rule, so tickets, docs and agent files stop citing it, unless `plot-twist` started this run. Done when `git diff` on each old record shows one added line and nothing removed.
7. **Point the guard back.** When the Guard names a real check, its failure message or header comment names the record number, so a reader who trips it finds the why. Done when the check's text holds the number, or the Guard says `Review only.`

Charter: C3, C4, C8 ([CHARTER.md](../../CHARTER.md)).
