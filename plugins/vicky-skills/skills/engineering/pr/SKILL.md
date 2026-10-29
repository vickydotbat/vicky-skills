---
name: pr
description: "Write or update a pull request body. Use when opening a pull request, after a push changes what it does, or when asked for a PR description."
---

# PR

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
- **One `Closes` line per ticket** the pull request finishes. A ticket it finishes only partly gets its body rewritten to what remains.
- **True of the diff.** After every push, read the body against `git diff <base>...HEAD` and rewrite superseded text in place. Done when every sentence matches the diff.
