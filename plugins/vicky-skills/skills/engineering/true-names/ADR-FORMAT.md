# Decision record format

Decision records live in `docs/adr/` as `NNNN-slug.md`, numbered one past the highest number there. A record is three lines, what, when and why, and nothing else.

```markdown
# ADR-NNNN: <what was decided, as one sentence>

Decided <YYYY-MM-DD>.

Because <the reason, as one sentence>.
```

- **What** is the choice, never how it is built. File, function and constant names stay in the code, and a value's own reason goes in a comment beside it.
- **Why** is the reason the code can't show: an outside limit, or the option turned down and what it would cost.

A record changes only when the decision does, never to follow the code. A changed decision rewrites its record whole under the same number, with the new date: git keeps the old one.

Check a record with `scripts/check-adr.sh <record>`. It fails on any line other than the three.
