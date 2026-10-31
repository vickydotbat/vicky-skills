# Domain docs

Read these before exploring the code, when they exist:

- `GLOSSARY.md` at the root, or every glossary `GLOSSARY-MAP.md` lists that touches the topic.
- Each decision record in `docs/adr/` (and a package's own `docs/adr/`) that touches the area.

ADR format: <`true-names`, or the repo-relative path of this repo's own record template>

Todo file: on

Test props: <where a live check's test props go, such as a test module or a seed script; never content that ships>

The `.todo` file at the root holds small items, one per line, too small for a ticket. Delete an item's line once it is done.

Use the glossary's words in tickets, tests and names. A word the glossary lacks is either invented (pick the glossary's word) or a gap (raise it with the `true-names` skill). When your work contradicts a decision record, say so and name it before you go on.
