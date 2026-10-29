# Tickets: GitLab

Tickets are GitLab issues in this repo. Work them with [`glab`](https://gitlab.com/gitlab-org/cli), which reads the repo from `git remote -v`. GitLab calls comments notes and pull requests merge requests (`glab mr ...`).

| Action | Command |
| --- | --- |
| Read, whole | `glab issue view <n> --comments` |
| File | `glab issue create --title "<title>" --description "<body>"` |
| Comment | `glab issue note <n> --message "<body>"` |
| Label | `glab issue update <n> --label <label>` (`--unlabel` to drop) |
| Close | post the reason as a note, then `glab issue close <n>` |

## Wayfinding operations

- **Map**: an issue labelled `wayfinder:map`.
- **Ticket**: an issue whose description starts with `Part of #<map>`, labelled `wayfinder:<kind>` for a decision ticket.
- **Blocking**: a native blocking link, added with the note `/blocked_by #<blocker>`. Where the plan lacks blocking links, a `Blocked by: #<n>` line tops the description.
- **Frontier**: the map's open children with no assignee and no open blocker (`glab api projects/:id/issues/:iid/links`).
- **Claim**: `glab issue update <n> --assignee @me`, before any other write.
