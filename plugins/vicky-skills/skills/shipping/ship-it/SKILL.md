---
name: ship-it
hands-off: [human-voice]
description: "Write or rewrite a pull request body in its one template. Use whenever a pull request opens, a stack submits new ones, a push makes the body untrue, or someone asks for a PR description."
---

# Ship it

> _Just the facts: every sentence of the body is true of the diff._

A pull request body tells a reviewer what changed, the proof that it works, and what merging risks. Every body in a repo takes the one template below. `pr-guard` refuses a body that lacks Status, Summary, Proof or Risk in a repo whose `docs/agents/issue-tracker.md` says `PR template: on`.

## Steps

1. **Gather.** Read `git diff <base>...HEAD`, `git log <base>..HEAD`, every ticket the branch, commits or current body names, and the current body when there is one (`gh pr view <n> --comments`, or `tea pr <n> --comments </dev/null`). Done when you hold the diff, the commits and each ticket's state.
2. **Write the body** to `<scratch>/pr-body.md` in the template, with `human-voice`, in the plain register and the repo glossary's words. A rewrite keeps every section and changes only what the diff made untrue. Done when every sentence is true of the diff, each glance question below has its Risk line, and a section with no evidence to fill it says "unchecked".
   Proven by: plugins/vicky-skills/evals/ship-it/glance-questions
3. **Apply it** with `--body-file`: `gh pr create --draft --title "<title>" --body-file <scratch>/pr-body.md`, `gh pr edit <n> --body-file <scratch>/pr-body.md`, or Gitea's `tea pr create --draft`/`tea pr edit <n>` with `--description "$(cat <scratch>/pr-body.md)" </dev/null`. Then read the pull request back (`gh pr view <n>`, or `tea pr <n> --comments </dev/null`) before you say it is open or its body is set. Done when the command ran, `pr-guard` let it through, and the read-back shows the body.

## Template

```markdown
## Status

`Done:` <what this pull request holds so far>
`Next:` <the next step>
`Waits on:` <who or what, or nobody>

Plan check: <what it found>

## Summary

<one or two sentences: what changes and why, then the smallest picture that shows the change>

## Examples

- <each approved example this pull request makes pass> (`<test name>`)

## Proof

- Tests: <the tests that ran, failing before and passing after>
- Mutation: <the `sentinels` report line per file, and the answer to each survivor>
- <the before and after screenshots, when the change is visible>

## Check these

- <a question the build answered on its own: the answer taken, and its commit>
- <a parked slice, and what it waits on>

## Risk

- Undo: <a revert undoes it | what a revert can't undo>
- Reach: <what else this change can break>

Closes <ticket>
```

- **Status says where the work stands**, so a fresh session can pick it up from the body alone. A skill that stops rewrites it in place, true at that moment. `Next:` names what the next session does. With nothing waiting, write `Waits on: nobody`. A waiting line names a person, a merge, a ticket or a check `gamma-shift` can read. A wait on the user starts `Waits on: you`, so the `.todo` springboard lists it. The `Plan check:` line is `do` step 2's; a body no `do` build wrote leaves it out.
- **The smallest picture.** Pick one: a `diff` of a call tree, file tree or state flow for a change to something that exists, a plain tree for something new, pseudocode for logic, or a Mermaid diagram for data passing between parts. Keep only the calls, files and states the reviewer needs.
- **Before and after.** A change you can see shows a before screenshot and an after screenshot, side by side. `do` step 3 says when the before shot is taken.
  Proven by: plugins/vicky-skills/evals/ship-it/before-and-after
- **Status, Summary, Proof and Risk always stay.** Leave out an optional section with nothing in it: no approved examples, no Examples section. Check these comes from `do` and is gone by the time the pull request is ready.
- **Settle the tickets** with `make-it-so`'s [SETTLE.md](../make-it-so/SETTLE.md) after every push, and keep this template while it rewrites the body. A body whose branch, commits and tickets name no ticket drops the `Closes` line.

## Glance questions

Glance question: anything a reviewer would ask before they trust the merge. Answer each one in Risk, unasked, before the user has to ask for it.

- **Every kind**: read the diff for each kind below, past what the file list shows, and give every question it raises a Risk line.
  - **Size**: a file count in the hundreds, images or other binaries, megabytes of growth, a generated or vendored folder.
  - **Ship**: a touched build input, manifest, packer list, lockfile or release step, and what now reaches users or a package.
  - **Behaviour**: a default, format, saved data, API, command or setting that changes for someone who did nothing.
  - **Running cost**: a new CI job, trigger or schedule, a slower path, more memory, requests or disk.
  - **Trust**: a new dependency, outside action, permission, secret, token scope, network call or outside input.
  - **Departure**: a way of doing a thing the repo already does differently, or a part left for later.
  Proven by: plugins/vicky-skills/evals/ship-it/glance-running-cost
- **Measured answers**: each Risk line holds a number, a file or a test, never "small", "safe" or "no risk" alone. `human-voice` cuts reassurance: a measured answer to a glance question is evidence, and stays.
  - **Count it**: the measured number, from `git diff --shortstat <base>...HEAD`, `du`, a timing or the build log, split into the bulk and the rest ("1,194 of the 1,204 files are previews").
  - **Say why it is there**, in one clause the reviewer can check.
  - **Bound its reach** by the file or test that limits it: the manifest, build list, ignore file, workflow trigger or test, named in code. Search the repo for that file before you write "unchecked".
  Proven by: plugins/vicky-skills/evals/ship-it/glance-questions

## State at every stop

At every stop, write the pull request body's Status section: a draft opened, a slice parked, a gate reached, the run ended. `do`, `warp`, `gamma-shift` and `make-it-so` point here.

Charter: C3, C4, C10 ([CHARTER.md](../../CHARTER.md)).
