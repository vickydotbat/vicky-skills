# Standards

The baseline every deathmatch opponent and reviewer holds a diff to, in any repo. It lives in the plugin so no repo has to repeat it: a repo's agent files point here and keep only what is theirs alone. The repo's own standards win where they speak: a documented repo rule that endorses something below suppresses the finding.

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
- **Lint gates.** A check worth having fails the build: warnings get ignored. It fails the build of the change that can fix it ("Gate where it is fixed"). A ban-list entry's message names the replacement. A suppression names one rule on one line, and an unused suppression is reported. Legacy code adopts a rule by reporting only issues new since a base revision.
- **Gate where it is fixed.** A blocking check fails only on what the change's own diff can fix. When passing needs another pull request, a later merge, or state outside the repository, move the check to where the whole state exists: a release, a sweep, or a rerun when the base moves. It stays a failure there, never a warning. A check that judged an asset upload against `main` failed until a second pull request dropped the row naming the file, and that one never reran it, so it moved to release.
  Proven by: plugins/vicky-skills/evals/deathmatch/gate-own-diff
- **No live citations.** Point at another text by its role, its link or a rule's leading word, never by copying its wording as if it still holds. A quote is a post-mortem only: past tense, dated, its source assumed dead ("the page said X at revision Y").

- **Claims.** A pull request's Proof says what ran, what was skipped and why, and what no one checked. A claim no run backs (a suite that never ran, a number never measured) is a defect.
- **Check ladder.** An agent never hands a person a check it could run: a unit test first, then a harness that drives the system, then a real client. An item handed over names the rung that stops short of it.
- **Proof by run.** A refactor proves the old behaviour still works with a green run, never by reading the diff. A clean compile proves nothing about what a change draws or does.
- **Guilty until proven innocent.** A change to what a person sees carries before and after captures of everything it touches. A missing pair is a rejection.
- **Blast radius.** A change writes only to what it owns. It never touches the user's own data folders, a shared checkout, another session's work, a live host or a public server, and it preserves unrelated changes.
- **Artifacts.** Generated output is changed through its generator, never by hand. Build output, binaries and game data stay out of git.
- **Scope.** A diff holds what the effort asked for and the fixes it found on the way. Unrelated cleanup goes to a ticket.
- **Survives restart.** State a user can notice survives a restart, a reboot and a fresh host. Memory is a cache, never the only copy. Nothing lasting lives in a temporary folder.
- **Public text.** Text that leaves the machine credits no AI, carries no agent-tool markers, and holds no local path, host or secret. Text a player or customer reads is approved by a person before it ships.
- **Truthful names.** A name, folder or namespace says what the thing does now. A change that makes a name stale renames or moves it in the same diff.
- **Take-over test.** Someone new can take over the code without private knowledge of the whole system.
- **Reuse the safety net.** Before adding a local guard, look for the one the system already has (a readiness flow, a scheduler, a migration step) and use it.
- **Quoted headings.** A heading another page quotes changes only in the same edit as every quote of it.

## Security

A broken rule here is a **hard** finding only when its proving run shows the break: cite the rule by its leading word and quote the run's output line. A finding whose run shows nothing is unproven and never blocks. The `security` skill runs each one as a level, and a rule joins this list only with a run that proves it.

- **Committed secrets.** No key, token or password sits in any commit of the history, old ones included. Rotating it is the fix. Deleting it from the latest commit is not. Proving run: `gitleaks git`.
- **Workflow injection.** A CI step never expands outside text (a pull request's title, body or branch name, an issue's text) inside its script. It passes the text through an environment variable. Proving run: `zizmor`.
- **Security policy.** The repo says how to report a weakness privately, in a `SECURITY.md`. Proving run: `scorecard --checks Security-Policy`.
- **Known vulnerabilities.** No dependency the build ships has a published CVE unless a fixed version is taken or the pull request says why not. Proving run: `vulnix` on a Nix build, else `scorecard --checks Vulnerabilities`.

## Design moves

How to build so the rules hold. A missed move is a **judgement** finding named by its leading word.

- **Illegal states unrepresentable.** Each `if` that guards a state asks: could the design leave this state out? One status field with three values, not three booleans; a menu that never offers a row the item can't use; a `WritableFolder` built once, not a path checked in every caller. Whitelist, never blacklist: a check names what is allowed, so a case nobody thought of is refused. The downstream checks then go. Keep one only beside a comment naming why the source can't be closed.
- **Fail fast.** Where the design can't rule a state out (a file, a player, another server), check it at the boundary it enters and stop with an error naming the value and what was expected. The assert stays on in release. A quiet default for a state that "can't happen" hides the bug where it started.
- **Bounded loops.** A loop that waits, retries, polls or walks input it doesn't own has a hard limit on turns or time, and hitting it is an error naming the limit. Pick it from the work: ten retries, thirty seconds, the list's length.
- **Root cause, not symptom.** When code you call does something unwanted, stop it where it is made. Undoing it in a second handler does the work twice and breaks when the first changes. One handler, one concern.
- **Events, not polling.** Code that waits for a change subscribes to the event raised where the work ends, adding one when none exists. Poll only where none of your code runs, with a comment naming why, and bound the poll.
- **One-way doors.** A save format, a stored variable, a database column, a wire protocol, a public API or command name, a file other tools read: changing one later means changing every copy and peer. Name it in the pull request, shape it as final, and give it a version or migration path. **Atomic schema changes**: the migration ships in the same diff, forward-only, never edited once applied, safe to run twice. Expand, then contract: a release only adds, and a drop waits until no build a rollback reaches reads the old shape, deleting its readers in the same diff.
- **Black-box tests.** A test asserts what its subject promises its caller (the forecast shown, the item in the pack, the line sent), never how it gets there (fetch counts, which helper ran, call order). Would a correct rewrite break the assertion? Then assert the outcome.

- **Hot paths.** Code on a path that runs constantly (a tick, an event per player, a request) costs next to nothing, never blocks on I/O, and scans only a bounded set. Lag for everyone is a bug even when the feature works. An exception never escapes a callback, hook or background task.
- **Persistent state.** A restore puts back what was saved and never refills, resets or clamps it. Time that passed while away is applied once, on return. A change that adds state ships a test that saves it, restores it fresh and finds it unchanged.

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
