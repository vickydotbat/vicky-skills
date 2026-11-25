---
name: ship-it
hands-off: [human-voice]
description: "Write or rewrite a pull request body in the repo's own template, or ship-it's default when it has none, and keep its Status. Use whenever a pull request opens, a stack submits new ones, a push makes the body untrue, or someone asks for a PR description."
---

# Ship it

> _Just the facts: every sentence of the body is true of the diff._

A pull request body tells a reviewer what changed, the proof that it works, and what merging risks. Maintainers own its shape, and this skill owns the method. **Which template:** the repo's own pull request template when it has one (`.github/pull_request_template.md`, `.gitea/PULL_REQUEST_TEMPLATE.md`, `docs/pull_request_template.md` or the root, in any letter case), with the docs it names. With none, a `docs/agents/` or CONTRIBUTING.md line on how bodies are written. Only where they say nothing, the template below. `pr-guard` refuses a body that lacks a heading the repo template asks for (every heading whose comment does not open with "Optional"), or Status, Summary, Proof or Risk when the repo has no template, in a repo whose `docs/agents/issue-tracker.md` says `PR template: on`.

## A repo's own template

- **Its headings, in its order, and no others.** Never add a heading the template lacks. A glance answer or a Risk line goes under the nearest heading it has: running cost under Performance, tests under Proof, undo and reach under the closest one.
  Proven by: plugins/vicky-skills/evals/ship-it/repo-template
- **Its comments are the maintainers' instructions.** Follow each one, then delete it: the body keeps no `<!--` comment.
  Proven by: plugins/vicky-skills/evals/ship-it/repo-template
- **A box only a person can vouch for** ("I understand this change") stays unticked. Say so in your reply, so the user ticks it.
  Proven by: plugins/vicky-skills/evals/ship-it/repo-template
- **Read it back** against the template and the docs it names before you apply it, and fix any heading, box or comment that doesn't match.
  Proven by: plugins/vicky-skills/evals/ship-it/repo-template

## Steps

1. **Gather.** Read `git diff <base>...HEAD`, `git log <base>..HEAD`, every ticket the branch, commits or current body names, and the current body when there is one (`gh pr view <n> --comments`, or `tea pr <n> --comments </dev/null`). Done when you hold the diff, the commits and each ticket's state.
2. **Write the body** to `<scratch>/pr-body.md` in the template "Which template" picked, and the Status comment to `<scratch>/pr-comment.md` when that template has no Status heading, with `human-voice`, in the plain register and the repo glossary's words. A rewrite keeps every section and changes only what the diff made untrue. Done when every sentence is true of the diff, each glance question below has its Risk line, and a section with no evidence to fill it says "unchecked".
   Proven by: plugins/vicky-skills/evals/ship-it/glance-questions
   Proven by: plugins/vicky-skills/evals/ship-it/repo-template
   Proven by: plugins/vicky-skills/evals/ship-it/how-to-try
3. **Apply it** with `--body-file`: `gh pr create --draft --title "<title>" --body-file <scratch>/pr-body.md`, `gh pr edit <n> --body-file <scratch>/pr-body.md`, or Gitea's `tea pr create --draft`/`tea pr edit <n>` with `--description "$(cat <scratch>/pr-body.md)" </dev/null`. Then read the pull request back (`gh pr view <n>`, or `tea pr <n> --comments </dev/null`) before you say it is open or its body is set. Done when the command ran, `pr-guard` let it through, and the read-back shows the body.

## Template

```markdown
## Status

`Done:` <what this pull request holds so far>
`Next:` <the next step>
`Waits on:` <who or what, or nobody>

## Summary

<what changes and why, two sentences at most>. <the smallest picture>

## Screenshots

| Before | After |
| --- | --- |
| <the bug ticket's shot, or the old look> | <the new look> |

## How to try it

1. <one action>
2. <one action>
3. <what you see now>, where before <what was seen>

## More cases

- <a neighbouring input, screen or setting that now works too>
- <the closest path this leaves unchanged>

## Proof

- Examples: <each approved example> (`<test name>`)
- Tests: <what ran, failing before and passing after>
- Mutation: <the sentinels line per file, and each survivor's answer>

## Risk

- Undo: <a revert undoes it | what a revert can't undo>
- Reach: <what else this can break, measured>

## Related

- <ticket or pull request on the same thing>

Closes <ticket>
```

- **Status says where the work stands**, so a fresh session can pick it up from the body alone. A skill that stops rewrites it in place, true at that moment. `Next:` names what the next session does. With nothing waiting, write `Waits on: nobody`. A waiting line names a person, a merge, a ticket or a check `gamma-shift` can read. A wait on the user starts `Waits on: you`, so the `.todo` springboard lists it. Its place is in "State at every stop" below.
  Proven by: plugins/vicky-skills/evals/ship-it/repo-template
- **Build-time extras.** While `do` builds, a `Plan check:` line sits under Status (`do` step 2's) and a `## Check these` section sits before Risk, one line per question answered on its own or slice parked. `make-it-so` deletes both before the pull request is ready, so the template leaves them out.
  Proven by: plugins/vicky-skills/evals/ship-it/lean-big-pr
- **Lean on a big pull request.** One line per item, the bulk counted, never listed: "41 tests renamed" beats 41 lines. A section that grows past ten lines keeps its five that matter most and counts the rest.
  Proven by: plugins/vicky-skills/evals/ship-it/lean-big-pr
- **The smallest picture.** Pick one: a `diff` of a call tree, file tree or state flow for a change to something that exists, a plain tree for something new, pseudocode for logic, or a Mermaid diagram for data passing between parts. Keep only the calls, files and states the reviewer needs.
- **Before and after.** A change you can see shows a before screenshot and an after screenshot, side by side in the Screenshots table. A fix for a bug ticket that holds a screenshot uses that shot as the before. With no such shot, the before is the old look taken from the default branch, or "new" when nothing existed. Never leave the cell empty or invent a shot. `do` step 3 says when the before shot is taken.
  Proven by: plugins/vicky-skills/evals/ship-it/before-and-after
- **Status, Summary, Proof and Risk always stay.** Leave out an optional section with nothing in it: Screenshots for a change nobody sees, How to try it and More cases for a change nobody can run (docs only, an internal refactor), Related when nothing is related. Write no "none found" line. Proof's Examples line lists each approved example with its test, and goes when there are none.
  Proven by: plugins/vicky-skills/evals/ship-it/how-to-try
- **How to try it** lists numbered steps a reviewer follows, one action each, ending on what they see now and what was seen before. Mark a step you could not run `unchecked`.
  Proven by: plugins/vicky-skills/evals/ship-it/how-to-try
- **More cases** names the neighbouring cases tried, each seen or `unchecked`, and the closest path the change leaves alone.
  Proven by: plugins/vicky-skills/evals/ship-it/how-to-try
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

At every stop, write the pull request's Status: a draft opened, a slice parked, a gate reached, the run ended. `do`, `warp`, `gamma-shift` and `make-it-so` point here, and read Status from where this says it lives, never from the body alone.

- **The template has a Status heading** (this one does): rewrite that section in place, and leave every other section byte for byte as it was.
  Proven by: plugins/vicky-skills/evals/ship-it/repo-template
- **The template has none**: Status lives in one pull request comment that starts with `Status` and holds the `Done:`, `Next:` and `Waits on:` lines. Find it with `gh pr view <n> --comments` (or `tea pr <n> --comments </dev/null`) and edit it in place (`gh api -X PATCH repos/{owner}/{repo}/issues/comments/<id> -f body=...`). Post it only when none exists, and never post a second. With no remote yet, write that comment to `<scratch>/pr-comment.md` beside the body.
  Proven by: plugins/vicky-skills/evals/ship-it/repo-template

Charter: C3, C4, C10 ([CHARTER.md](../../CHARTER.md)).
