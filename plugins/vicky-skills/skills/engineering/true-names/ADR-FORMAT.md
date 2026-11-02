# Decision record format

## Scope

A record holds an architecture rule, macro and never micro: a broad, reusable why that many decisions rest on and the code can't show. Before you write one, state its rule in one sentence. A rule that names one class, subclass, spell, feat, item, race, window or value is one feature's why: write it as a comment at the code that builds it, or in the project's system design docs, and write no record. Keep documentation to what the code can't explain.

## Shape

Decision records live in `docs/adr/` as `NNNN-slug.md`, numbered one past the highest number there. A record is a title, a category, a date, then a Brief and a Rationale of one short paragraph each, in at most 100 words for the whole file.

```markdown
# ADR-NNNN: <what was decided, as one sentence>

Category: <one category from the list below>.

Decided <YYYY-MM-DD>.

## Brief

<one short paragraph: the decision, as a rule a reader applies>

## Rationale

<one short paragraph: why, the reason the code can't show>
```

- **Title and Brief** give the choice, never how it is built. File, function and constant names stay in the code, and a value's own reason goes in a comment beside it.
- **Rationale** gives the outside limit, or the option turned down and what it would cost.
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

An older record may hold a `Because <the reason>.` line in place of the two sections, in at most 55 words. It stays as it is. Every new record takes the Brief and Rationale.

Check a record with `scripts/check-adr.sh <record>`. It fails on any other line, a missing section, a second paragraph in a section, a `Because` line mixed with the sections, a category off the list, a backticked code name, or a word past the limit.
