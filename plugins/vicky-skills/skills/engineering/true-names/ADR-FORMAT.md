# Decision record format

Decision records live in `docs/adr/` as `NNNN-slug.md`, numbered one past the highest number there. A record is four lines, what, category, when and why, in at most 55 words.

```markdown
# ADR-NNNN: <what was decided, as one sentence>

Category: <one category from the list below>.

Decided <YYYY-MM-DD>.

Because <the reason, as one sentence>.
```

- **What** is the choice, never how it is built. File, function and constant names stay in the code, and a value's own reason goes in a comment beside it.
- **Why** is the reason the code can't show: an outside limit, or the option turned down and what it would cost.
- **Category** is exactly one of these, and the first that fits wins:
  - **Architecture**: the system's parts and how they talk to each other.
  - **Data**: what is stored, who owns it, and its form.
  - **Interface**: what users or other systems see and call.
  - **Infrastructure**: where and how the system runs, builds and ships.
  - **Security**: who can do what, and what is protected.
  - **Dependencies**: a library, service or platform the project relies on.
  - **Tooling**: how the team builds, tests and checks its work.
  - **Process**: how the team works: reviews, releases, conventions.
  - **Other**: anything none of the above fits.

A record changes only when the decision does, never to follow the code. A changed decision gets a new record, and the old one gains one last line, `Superseded by ADR-NNNN.`, with the rest left as it was. A record in another repository is named with that repository first: `Superseded by sow-platform ADR-0064.`

Check a record with `scripts/check-adr.sh <record>`. It fails on any other line, a category off the list, a backticked code name, or more than 55 words.
