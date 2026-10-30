# Review principles

The baseline every review holds a diff to, in any repo. The repo's own standards win where they speak: a documented repo rule that endorses something below suppresses the finding.

## Rules

A broken rule is a **hard** finding.

- **One point of entry.** Every need two places share (a rule, a formula, a lookup, a guard, how a thing is shown) has one entry, and every caller goes through it. A second entry is a defect unless a one-line comment beside it says why one entry cannot serve both callers. Search for the code's form (the same expression, the same fields read), never only its name: a copy hides under any name. A second entry in a file the diff touches is merged in the same change.
- **Deep modules.** A module hides more than its interface shows: a caller needs less to use it than the module needs to work. A new module passes the **deletion test**: deleting it would spread its complexity into its callers. A module that fails it (an interface nearly as big as its body, a layer that only passes calls through, a function pulled out for a test while the bug lives in its callers) is merged into its caller or the module it wraps.
- **Data from its source.** A value with a home (a table, a config file, a schema, a constant the platform ships) is read from that home. A hand-typed copy in code, text or a test is a defect.
- **One copy of logic.** Duplicated logic carries a written reason beside it, or it is merged.
- **Smallest complete change.** An abstraction, option, parameter or layer needs a current caller. Deletion beats addition. The language's standard library and the repo's installed dependencies come before new code.
- **A test proves a result.** It names the behaviour it holds and the change that turns it red. A test whose only possible red is a refactor, a content edit or a library upgrade proves nothing: a read-back of its input, a pin on shipped content, a check of a signature, a second proof of a result another case owns, or a proof of library behaviour with no production code on the path.
- **Mutation proves the tests.** Changed decision logic (rules, limits, parsers) gets a run of the mutation tool the repo's docs name. Each surviving mutant gets a test that kills it, the deletion of the code it lived in, or a comment saying why no input tells it apart. The pull request gives the killed and survived counts, or says the repo has no mutation tool.
- **Approved examples are the contract.** A test marked `approved-spec` changes only after the human approves the new example text.
- **A value that changes is read where it is kept.** Docs give a count, size or version by where to read it, never as a number that goes stale.

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
