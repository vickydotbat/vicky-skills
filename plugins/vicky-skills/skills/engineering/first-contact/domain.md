# Domain docs

Read these before exploring the code, when they exist:

- `GLOSSARY.md` at the root, or every glossary `GLOSSARY-MAP.md` lists that touches the topic.
- Each decision record in `docs/adr/` (and a package's own `docs/adr/`) that touches the area.

ADR format: <`ADR-FORMAT.md`, or the repo-relative path of this repo's own record template>

Sketches: <the repo-relative folder for drawing-board sketches, or delete this line to keep each sketch beside the code it designs>

Todo file: on

Checklist lint: full

Write `Checklist lint: basic` to keep only the person, kit and proof checks on over-to-you pages.

The `.todo` file at the root holds small items, one per line, too small for a ticket. Delete an item's line once it is done.

Use the glossary's words in tickets, tests and names. A word the glossary lacks is either invented (pick the glossary's word) or a gap (raise it with the user, and write the settled word into the glossary). When your work contradicts a decision record, say so and name it before you go on.
