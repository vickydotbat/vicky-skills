# Decision record format

Decision records live in `docs/adr/` as `NNNN-slug.md`, numbered one past the highest number there. A record is three lines, what, when and why, in at most 50 words.

```markdown
# ADR-NNNN: <what was decided, as one sentence>

Decided <YYYY-MM-DD>.

Because <the reason, as one sentence>.
```

- **What** is the choice, never how it is built. File, function and constant names stay in the code, and a value's own reason goes in a comment beside it.
- **Why** is the reason the code can't show: an outside limit, or the option turned down and what it would cost.

A record changes only when the decision does, never to follow the code. A changed decision gets a new record, and the old one gains one last line, `Superseded by ADR-NNNN.`, with the rest left as it was.

Check a record with `scripts/check-adr.sh <record>`. It fails on any other line, a backticked code name, or more than 50 words.
