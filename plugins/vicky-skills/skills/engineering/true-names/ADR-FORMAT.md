# Decision record format

Decision records live in `docs/adr/` as `NNNN-slug.md`, numbered one past the highest number there.

```markdown
# ADR-NNNN: <the decision, as a sentence>

- **Status:** Accepted
- **Date:** <YYYY-MM-DD>

<What forced the choice, what was decided, and why, in a few sentences.>
```

Add a section only when it earns its place:

- **Considered options**: when a rejected option will be suggested again.
- **Consequences**: when a downstream effect isn't obvious.
- **Superseded by ADR-NNNN**: on the old record, when a newer one replaces it. Edit the old record's status, and leave its text as history.

Worth a record: the system's overall form, how parts talk to each other, a technology that would take months to swap, who owns what data, a deliberate departure from the obvious path, a constraint the code can't show.
