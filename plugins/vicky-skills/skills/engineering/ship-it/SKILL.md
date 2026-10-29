---
name: ship-it
description: "Write or update a pull request body. Use when opening a pull request, after a push changes what it does, or when asked for a PR description."
---

# Ship it

A pull request body tells a reviewer what changed, the proof that it works, and what merging risks. Write it with the `human-voice` skill, in the clinical register, using the repo glossary's words.

```markdown
## Summary

<one or two sentences, then the smallest picture that shows the change>

## Examples

- <each approved example this pull request makes pass> (`<test name>`)

## Proof

- Tests: <the tests that ran, failing before and passing after>
- Mutation: <killed and survived counts, and the answer to each survivor>
- <a screenshot, when the change is visible>

## Risk

- Undo: <a revert undoes it | what a revert can't undo>
- Reach: <what else this change can break>

Closes <ticket>
```

- **The smallest picture.** Pick one: a `diff` of a call tree, file tree or state flow for a change to something that exists, a plain tree for something new, pseudocode for logic, or a Mermaid diagram for data passing between parts. Keep only the calls, files and states the reviewer needs.
- **Leave out empty sections.** No approved examples, no Examples section. Where the repo has no mutation tool, the Mutation line says so.
- **Settle the tickets and keep the body true** with the `loose-ends` skill, after every push.
