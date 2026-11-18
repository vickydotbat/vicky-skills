# Review principles

The baseline every review holds a diff to, in any repo. The repo's own standards win where they speak: a documented repo rule that endorses something below suppresses the finding.

## Rules

A broken rule is a **hard** finding. Each rule opens with its leading word; cite it by that word.

- **Single source of truth.** Every need two places share (a rule, a formula, a lookup, a guard, how a thing is shown) has one entry, and every caller goes through it. A second entry needs a one-line comment saying why one entry can't serve both. Search for the code's form (the same expression, the same fields read), never only its name. Merge a second entry in a file the diff touches. An API that works only when its caller remembers a second call is a second entry: the entry makes that call itself. Where the repo bans raw calls, a new entry bans its raw call in the same diff.
- **Deep modules.** A caller needs less to use a module than the module needs to work. A new module passes the **deletion test**: deleting it would spread its complexity into its callers. One that fails (an interface nearly as big as its body, a pass-through layer, a function pulled out for a test while the bug lives in its callers) merges into its caller or the module it wraps.
- **Data-driven.** A value with a home (a table, a config file, a schema, a platform constant) is read from that home. A hand-typed copy in code, text or a test is a defect.
- **YAGNI.** An abstraction, option, parameter or layer needs a current caller. Deletion beats addition: when in doubt, cut the fat. The standard library and installed dependencies come before new code, and a new dependency waits for the human's yes. No production surface exists only for a test, except an input no test can hold still (the clock, a die, a delay), which the caller passes in.
- **Boy-scout rule.** A smell in code the diff touches is fixed in the diff. One outside it gets a ticket, never dropped. "Rare path" is no reason to keep one.
- **No placebos.** A test names the behaviour it holds and the change that turns it red, and is named after that relation, never after a number. A test whose only red is a refactor, a content edit or a library upgrade proves nothing: a read-back, a content pin, a signature check, a re-proof of another case's result, a library proof.
- **Never test prose.** No test, hook or check asserts on the wording of a doc, a skill, a record, a comment or a message. Prove the behaviour the prose describes, or lint its form: a dead link, a missing file, frontmatter, or a marker tooling parses (a step's `Done when`).
- **Boundary values.** A toggle has a case for each value and for flipping back. A flow that spends or moves something starts one case empty and one full. A configured value is tested where a wrong formula gives another answer. A replaced path is asserted against the old one over the same data.
- **Cheap tests.** Each fixture owns its namespace (a schema, a temporary folder). One command runs once per fixture, and every assertion hangs off that run. An entry point that starts a real stack, server or editor runs dry or in a copied tree with stand-ins. `sentinels`' SPEED.md holds the rest.
- **Flaky is red.** A test that passed and now fails with no change to its code is a bug until shown otherwise. Read the values it saw before you touch it: a setup tweak that turns it green hides the cause.
- **Mutants die.** Changed decision logic (rules, limits, parsers) gets a run of the repo's mutation tool. Each survivor gets a test that kills it, deletion of its code, or a comment saying why no input tells it apart. The pull request gives killed and survived counts, or says the repo has none.
- **Approved examples.** A test marked `approved-spec` changes only after the human approves the new example text.
- **Why-comments.** Write no comment by default. A comment is one line of why the code can't show. Narration, history, change notes and banners go to the ticket or the pull request. A why over two lines is a design doc or a decision record.
- **Zero drift.** A decision record changes only through `decision-record`. Before a change touches what a record or why-comment covers, read it. A diff that goes against the why, or deletes it, gives its new reason in the same diff: a superseding record, or the comment rewritten. A diff that does neither is drift.
- **No stale numbers.** Docs give a count, size or version by where to read it, never as a number.
- **Markdown scope.** Repo Markdown is current reference, law or a decision record. Plans, specs, handoffs, trackers and session learnings go to the tracker. What a session learns that the code can't show goes where a reader already looks: a cause found after failed fixes, on its ticket; a dropped approach, as a why-comment beside the chosen one; a correction to how work is done, as a law in the repo's standards.
- **Lint gates.** A check worth having fails the build: warnings get ignored. A ban-list entry's message names the replacement. A suppression names one rule on one line, and an unused suppression is reported. Legacy code adopts a rule by reporting only issues new since a base revision.
- **No live citations.** Point at another text by its role, its link or a rule's leading word, never by copying its wording as if it still holds. A quote is a post-mortem only: past tense, dated, its source assumed dead ("the page said X at revision Y").

## Design moves

How to build so the rules hold. A missed move is a **judgement** finding named by its leading word.

- **Illegal states unrepresentable.** Each `if` that guards a state asks: could the design leave this state out? One status field with three values, not three booleans; a menu that never offers a row the item can't use; a `WritableFolder` built once, not a path checked in every caller. Whitelist, never blacklist: a check names what is allowed, so a case nobody thought of is refused. The downstream checks then go. Keep one only beside a comment naming why the source can't be closed.
- **Fail fast.** Where the design can't rule a state out (a file, a player, another server), check it at the boundary it enters and stop with an error naming the value and what was expected. The assert stays on in release. A quiet default for a state that "can't happen" hides the bug where it started.
- **Bounded loops.** A loop that waits, retries, polls or walks input it doesn't own has a hard limit on turns or time, and hitting it is an error naming the limit. Pick it from the work: ten retries, thirty seconds, the list's length.
- **Root cause, not symptom.** When code you call does something unwanted, stop it where it is made. Undoing it in a second handler does the work twice and breaks when the first changes. One handler, one concern.
- **Events, not polling.** Code that waits for a change subscribes to the event raised where the work ends, adding one when none exists. Poll only where none of your code runs, with a comment naming why, and bound the poll.
- **One-way doors.** A save format, a stored variable, a database column, a wire protocol, a public API or command name, a file other tools read: changing one later means changing every copy and peer. Name it in the pull request, shape it as final, and give it a version or migration path. **Atomic schema changes**: the migration ships in the same diff, forward-only, never edited once applied, safe to run twice. Expand, then contract: a release only adds, and a drop waits until no build a rollback reaches reads the old shape, deleting its readers in the same diff.
- **Black-box tests.** A test asserts what its subject promises its caller (the forecast shown, the item in the pack, the line sent), never how it gets there (fetch counts, which helper ran, call order). Would a correct rewrite break the assertion? Then assert the outcome.

## Smells

Each smell is a **judgement** finding: label it ("possible Feature Envy") and quote the hunk.

- **Mysterious Name**: a name that doesn't say what the thing does or holds. → Rename it. If no honest name comes, the design is murky.
- **Duplicated Code**: the same logic in more than one hunk or file. → Extract it and call it from both.
- **Feature Envy**: a method that reads another object's data more than its own. → Move it onto that data.
- **Data Clumps**: the same fields or parameters keep travelling together. → Bundle them into one type.
- **Primitive Obsession**: a primitive standing in for a domain concept. → Give the concept its own small type.
- **Repeated Switches**: the same `switch` or `if` cascade on the same type recurs. → One map or polymorphism both sites share.
- **Shotgun Surgery**: one logical change forces scattered edits. → Gather what changes together.
- **Divergent Change**: one module edited for unrelated reasons. → Split it by reason.
- **Speculative Generality**: hooks or parameters for needs nobody has. → Delete them.
- **Message Chains**: long `a.b().c().d()` walks. → Hide the walk behind one method.
- **Middle Man**: a class that mostly delegates. → Call the real target.
- **Refused Bequest**: an implementer that ignores most of what it inherits. → Use composition.
