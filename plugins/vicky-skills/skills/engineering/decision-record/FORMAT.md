# Decision record format

The structure follows the community ADR guide (architecture-decision-record on GitHub): Nygard's Status, Context, Decision and Consequences, plus a Guard section for the guide's fitness function, an automated check that keeps a decision true.

## Scope

Which repos take this format: see the skill's opening ([SKILL.md](SKILL.md)). Write a record only for a decision that is hard to reverse, would surprise a reader without context, and came from a real trade-off.

A record holds an architecture rule, macro and never micro: a broad, reusable why that many decisions rest on and the code can't show. Before you write one, state its rule in one sentence and name the later decisions it will govern. When you can't name any, it is a code comment. A rule that names one class, item, window or value is one feature's why: write it as a comment at the code that builds it, and write no record. A change against a record or a why comment follows the review principles' "No drift from a recorded why" ([PRINCIPLES.md](../review/PRINCIPLES.md)).

## Stays true forever

A kept record is never edited, so every sentence in it must stay true after any pivot. A record that a later change of mind makes false has drifted, and an edit to fix it breaks that rule. A record with nothing left true is retired instead, as Status lines says.

- **Facts in the dated past.** Context states what was true and when: "By 2026-08-31, copies had gone stale." Never a present-tense claim about the system ("the server reads X"): the code owns the present.
- **The rule is conditional.** The Decision opens with `While` and names the forces it rests on: "While F1 and F2 hold, ...". When a force stops holding, the rule stops applying, and the record stays true.
- **No names that rot.** No file, function, constant, version, count, person or team name. Name a thing by its role.
- **Append, never edit.** After acceptance, a kept record's only change is a new last line in Status. A retired record is deleted whole, never edited.

## Shape

Records live in `docs/adr/` as `NNNN-<imperative-slug>.md`, numbered one past the highest number there, the slug a present-tense verb phrase (`0012-read-loaded-columns.md`). At most 180 words for the whole file.

```markdown
# ADR-NNNN: <imperative verb phrase: what is decided>

Category: <one category from the list below>.

## Status

Accepted YYYY-MM-DD.

## Context

- F1: <a dated, past-tense fact about an outside force>
- F2: <another, when there is one>

## Decision

While F1 holds, <the rule a reader applies>.

## Consequences

<one paragraph: what gets easier, what gets harder, each break (a stored form, public call or layout that changes) with its migration or "No migration:" and who it leaves behind, the option turned down and its cost>

## Guard

<one paragraph: the check that fails when code drifts from the rule, named by role, or "Review only." when none exists yet>
```

- **Title and Decision** give the choice, never how it is built.
- **Context** holds one to five forces, each a `- F<n>: ` line. A force is an outside limit: a platform, a cost, a law, a measured failure. A preference is not a force.
- **Category** is exactly one of these, the first that fits:
  - **Architecture**: the system's parts and how they talk to each other.
  - **Data**: what is stored, who owns it, and its form.
  - **Interface**: what users or other systems see and call.
  - **Infrastructure**: where and how the system runs, builds and ships.
  - **Security**: who can do what, and what is protected.
  - **Dependencies**: a library, service or platform the project relies on.
  - **Tooling**: how the team builds, tests and checks its work.
  - **Process**: how the team works: reviews, releases, conventions.
  - **Other**: anything none of the above fits.
- **Guard** names a real check (a test, lint, CI step or hook) that exists in the repo, or says `Review only.` A `Review only.` record is a gap to close: a guard added later goes into a new record that amends it.

## Status lines

Status opens with `Accepted YYYY-MM-DD.` and later gains only appended lines, each dated, each naming the record that caused it:

- `Superseded by ADR-NNNN on YYYY-MM-DD: F<n> no longer holds.` The new record replaces the rule, but a fact this record states still holds. Its Context says what changed in that force.
- `Amended by ADR-NNNN on YYYY-MM-DD.` The new record adds to the rule (a guard, a narrower case) and this one still applies.

A record with nothing left true gets no Status line: it is retired. The new record's Consequences hold `Retires ADR-NNNN: <why>.`, and the old file is deleted in the same commit. A wiki keeps a tombstone page that points at the new record. The record check refuses a Retires line whose record still sits in the same folder.

A record in another repository is named with that repository first: `Superseded by platform ADR-0064 on 2026-11-13: F1 no longer holds.`

## Older shapes

Records written before this format keep their shape and are never rewritten: a `Decided YYYY-MM-DD.` line, then either a `Because <reason>.` line (at most 55 words) or `## Brief` and `## Rationale` sections (at most 100 words), with an optional last `Superseded by [<repo> ]ADR-NNNN.` line. A new record never takes an older shape. A new record that supersedes an old one gives the old one that last line.

## Check

Run `scripts/check-adr.sh <record>...`. Each failure prints its reason. A record in a repo template takes `--template`: no code in backticks, at most 180 words, a Decision line opening `While`, and a Consequences and a Guard heading.
