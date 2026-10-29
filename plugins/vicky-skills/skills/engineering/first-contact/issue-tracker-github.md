# Tickets: GitHub

Tickets are GitHub issues in this repo. Work them with `gh`, which reads the repo from `git remote -v`.

| Action | Command |
| --- | --- |
| Read, whole | `gh issue view <n> --comments` |
| File | `gh issue create --title "<title>" --body-file <file>` |
| Comment | `gh issue comment <n> --body-file <file>` |
| Label | `gh issue edit <n> --add-label <label>` (`--remove-label` to drop) |
| Close | `gh issue close <n> --comment "<why>"` |
| Make a child | `gh issue create --parent <map> ...`, or `gh issue edit <map> --add-sub-issue <child>` |

A bare `#42` can be an issue or a pull request. Try `gh pr view 42 --comments` first, then the issue.

## Wayfinding operations

- **Map**: an issue labelled `wayfinder:map`.
- **Ticket**: a sub-issue of the map, labelled `wayfinder:<kind>` for a decision ticket.
- **Blocking**: GitHub's issue dependencies. Add one with `gh api --method POST repos/<owner>/<repo>/issues/<child>/dependencies/blocked_by -F issue_id=<blocker database id>`, where the database id is `gh api repos/<owner>/<repo>/issues/<n> --jq .id`. Without dependencies, a `Blocked by: #<n>` line tops the child's body.
- **Frontier**: the map's open sub-issues with no assignee and no open blocker (`issue_dependencies_summary.blocked_by` is 0).
- **Claim**: `gh issue edit <n> --add-assignee @me`, before any other write.
