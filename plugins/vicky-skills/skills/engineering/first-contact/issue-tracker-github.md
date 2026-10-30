# Tickets: GitHub

Tickets are GitHub issues in this repo. Work them with `gh`, which reads the repo from `git remote -v`.

| Action | Command |
| --- | --- |
| Read, whole | `gh issue view <n> --comments` |
| File | `gh issue create --title "<title>" --body-file <file>` |
| Comment | `gh issue comment <n> --body-file <file>` |
| Label | `gh issue edit <n> --add-label <label>` (`--remove-label` to drop) |
| Close | `gh issue close <n> --comment "<why>"` |
| Make a child | `gh issue create --parent <chart> ...`, or `gh issue edit <chart> --add-sub-issue <child>` |

A bare `#42` can be an issue or a pull request. Try `gh pr view 42 --comments` first, then the issue.

## Star chart operations

- **Star chart**: an issue labelled `starchart:chart`.
- **Ticket**: a sub-issue of the chart, labelled `starchart:<kind>` unless it is a star.
- **Blocking**: GitHub's issue dependencies. Add one with `gh api --method POST repos/<owner>/<repo>/issues/<child>/dependencies/blocked_by -F issue_id=<blocker database id>`, where the database id is `gh api repos/<owner>/<repo>/issues/<n> --jq .id`. List a ticket's blockers with `gh api repos/<owner>/<repo>/issues/<n>/dependencies/blocked_by`. Without dependencies, a `Blocked by: #<n>` line tops the child's body.
- **Frontier**: the chart's open sub-issues with no assignee and no open blocker (`issue_dependencies_summary.blocked_by` is 0).
- **Chart**: a Mermaid block under `## Chart`. GitHub draws it.
- **Claim**: `gh issue edit <n> --add-assignee @me`, before any other write.

## Waiting work

A waiting ticket is assigned to the user and can't go on until the thing its `Waits on:` line names is done. `loose-ends` parks one, and `gamma-shift` works through them.

- **List tickets waiting on you**: `gh issue list --assignee @me --state open --search '"Waits on:" in:body'`.
- **Park a ticket**: `gh issue edit <n> --add-assignee @me`, then add a `Waits on: <who or what>` line to the body. GitHub has no not-started state: an open, assigned ticket with that line is waiting.
- **Claim a waiting ticket**: delete its `Waits on:` line, before any other write.
