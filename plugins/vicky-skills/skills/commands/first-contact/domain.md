# Domain docs

Read these before exploring the code, when they exist:

- `GLOSSARY.md` at the root, or every glossary `GLOSSARY-MAP.md` lists that touches the topic.
- Each decision record in `docs/adr/` (and a package's own `docs/adr/`) that touches the area.

ADR format: <`decision-record`, or the repo-relative path of this repo's own record template>

Sketches: <the repo-relative folder for drawing-board sketches, or delete this line to keep each sketch beside the code it designs>

Credits: <the repo-relative file that credits outside tools, libraries, fonts and assets, such as README.md, or `off`>

Shellcheck: on <or `off`, to stop `shellcheck-guard` checking a branch's shell files before a push>

Todo file: on

Chart cap: 8

Found work check: on

Stale text: on

Write `Stale text: off` to stop `git-guard` and `pr-guard` from refusing a commit message or pull request text that goes stale: a present-tense count, or a word such as "currently".

Patch-tell hint: on

Write `Patch-tell hint: off` to stop the reminder when an edit to a CI workflow adds a patch tell: a retry, a sleep, `continue-on-error`, a switched-off step, a skipped test or a raised timeout.

Law proofs: on

Write `Law proofs: off` to stop `law-lint.sh` listing rule lines that name no `Proven by:` check, and to stop deathmatch and make-it-so running a Laws line.

Post-mortems: docs/post-mortems/

Write where this repo keeps post-mortems (a folder or a wiki namespace), or `Post-mortems: off` to stop `post-mortem` writing them and its check.

Pre-mortems: on

Write `Pre-mortems: off` to stop the Foreseen check before a star chart is filed.

Earlier attempts: on

Write `Earlier attempts: off` to stop the Earlier attempts check before a star chart is filed.

Checklist lint: full

Write `Checklist lint: basic` to keep only the person, kit and proof checks on over-to-you pages.

The `.todo` file at the root holds small items, one per line, too small for a ticket. Delete an item's line once it is done.

Use the glossary's words in tickets, tests and names. A word the glossary lacks is either invented (pick the glossary's word) or a gap (raise it with the user, and write the settled word into the glossary). When your work contradicts a decision record, say so and name it before you go on.
