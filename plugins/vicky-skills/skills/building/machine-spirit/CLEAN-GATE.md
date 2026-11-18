# The clean gate

The shape every pull-request CI takes in a repository the user owns. A repository the user doesn't own keeps its own shape.

A **clean gate** is one workflow that always starts on a pull request, refuses a draft at its first step, and runs only the jobs a path map selects from the diff.

## The three parts

1. **One gate that always starts.** The pull-request workflow has no `paths` or `paths-ignore` filter. A workflow that never starts reports no status, and a required check that never reports blocks the merge. Job selection happens inside the run, with `if:` on each job. A job skipped by `if:` reports `skipped`, which passes a required check.
2. **A draft gate.** The first job's first step fails a draft, before any checkout. Every other job `needs:` that job, so a draft runs nothing else. A failure is the point: a skipped gate reports as passed and lets a draft merge.
3. **A path map with a `map-check`.** One script reads `git diff --name-only <base> HEAD` on stdin and prints `<target>=true|false` per target, plus `unknown=true|false`. A path no arm matches selects every target and sets `unknown`. A `map-check` job runs when `unknown` is true and fails, naming the unmapped paths from the map's log. The map job itself never fails on an unmapped path: its failure would skip every job that needs it.

A repository with a single cheap job (a few seconds of tests) needs no path map. It still gets parts 1 and 2.

## Draft detection, per forge

| Forge | A draft is | Trigger | Becomes ready by |
| --- | --- | --- | --- |
| GitHub | `github.event.pull_request.draft == true` | `pull_request: types: [opened, synchronize, reopened, ready_for_review]` | Marking it ready, which fires `ready_for_review` |
| Gitea | A title starting with `WIP:`, case-insensitive | Bare `pull_request` | Dropping `WIP:`, then a push or a close and reopen. A title edit alone starts no run. |

On GitHub, `ready_for_review` must be in `types`. Without it, the draft's last red run stays the result until the next push.

## Templates

GitHub:

```yaml
on:
  pull_request:
    types: [opened, synchronize, reopened, ready_for_review]

jobs:
  affected:
    runs-on: ubuntu-latest
    outputs:
      unknown: ${{ steps.map.outputs.unknown }}
      <target>: ${{ steps.map.outputs.<target> }}
    steps:
      - name: Refuse a draft
        if: github.event.pull_request.draft
        run: |
          echo "draft: CI runs once the pull request is marked ready" >&2
          exit 1
      - uses: actions/checkout@<pinned sha>
        with:
          fetch-depth: 0
      - name: Map changed paths to targets
        id: map
        env:
          BASE_SHA: ${{ github.event.pull_request.base.sha }}
        run: git diff --name-only "$BASE_SHA" HEAD | <map script> | tee -a "$GITHUB_OUTPUT"

  map-check:
    needs: affected
    if: needs.affected.outputs.unknown == 'true'
    runs-on: ubuntu-latest
    steps:
      - run: |
          echo "a changed path is not in the map; every job ran. Add the path to the map." >&2
          exit 1

  <target>:
    needs: affected
    if: needs.affected.outputs.<target> == 'true'
```

Gitea: the same jobs, with a bare `on: pull_request` and this first step:

```yaml
      - name: Refuse a draft
        env:
          TITLE: ${{ github.event.pull_request.title }}
        run: |
          shopt -s nocasematch
          if [[ "$TITLE" == "WIP:"* ]]; then
            echo "draft: CI runs once WIP: is gone; push, or close and reopen" >&2
            exit 1
          fi
```

## The map script

- Read paths on stdin, one per line, exactly as git prints them. Every pattern carries its folder prefix from the repository root.
- Put the prose arm first (`*.md`), so a docs-only change selects only the docs target, or nothing.
- Print one line per target on stderr saying which path selected it, or that nothing did. A reader of a green run tells "nothing to do" from "ran and passed" by it.
- Give the map a contract test: a table of sample paths and the targets each selects, including a docs-only path whose row says every build target is false, and an unmapped one. Every new file kind adds an arm and a row. CI runs it whenever the map or its test changes.

## Auditing a repository

A repository fails the audit when any of these holds:

- A `pull_request` workflow runs real work on a draft: no draft gate, or a gate that skips instead of failing.
- A pull-request workflow carries `paths` or `paths-ignore` and one of its jobs is a required check.
- A docs-only or decision-record-only path selects a build target, or has no arm.
- A path map exists with no contract test, or its test has no docs-only row.
- A path map exists with no `map-check`, or resolves an unknown path to "run nothing".
- On GitHub, a draft gate without `ready_for_review` in `types`.

Fix each one in the repository's own pull request, with steps 1 to 7 of the skill.
