---
name: ship-it
description: "Write or update a pull request body. Use when opening a pull request, after a push changes what it does, or when asked for a PR description."
---

# Ship it

> _Just the facts: every sentence of the body is true of the diff._

A pull request body tells a reviewer what changed, the proof that it works, and what merging risks. Write it with the `human-voice` skill, in the plain register, using the repo glossary's words.

```markdown
## Status

`Done:` <what this pull request holds so far>
`Next:` <the next step>
`Waits on:` <who or what, or nobody>

## Summary

<one or two sentences, then the smallest picture that shows the change>

## Examples

- <each approved example this pull request makes pass> (`<test name>`)

## Proof

- Tests: <the tests that ran, failing before and passing after>
- Mutation: <the `sentinels` report line per file, and the answer to each survivor>
- <a screenshot, when the change is visible>

## Check these

- <a question the build answered on its own: the answer taken, and its commit>
- <a parked slice, and what it waits on>

## Risk

- Undo: <a revert undoes it | what a revert can't undo>
- Reach: <what else this change can break>

Closes <ticket>
```

- **Status says where the work stands**, so a fresh session can pick it up from the body alone. A skill that stops rewrites it in place, true at that moment. `Next:` names what the next session does. With nothing waiting, write `Waits on: nobody`. A waiting line names a person, a merge, a ticket or a check `gamma-shift` can read. A wait on the user starts `Waits on: you`, so the `.todo` springboard lists it.
- **The smallest picture.** Pick one: a `diff` of a call tree, file tree or state flow for a change to something that exists, a plain tree for something new, pseudocode for logic, or a Mermaid diagram for data passing between parts. Keep only the calls, files and states the reviewer needs.
- **Leave out empty sections.** No approved examples, no Examples section. Check these comes from `do` and is gone by the time the pull request is ready.
- **Settle the tickets and keep the body true** with the `loose-ends` skill, after every push. Done when every sentence of the body is true of the final diff; a section you cannot fill from evidence says "unchecked".
