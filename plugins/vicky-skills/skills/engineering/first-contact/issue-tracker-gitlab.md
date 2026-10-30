# Tickets: GitLab

Tickets are GitLab issues in this repo. Work them with [`glab`](https://gitlab.com/gitlab-org/cli), which reads the repo from `git remote -v`. GitLab calls comments notes and pull requests merge requests (`glab mr ...`).

| Action | Command |
| --- | --- |
| Read, whole | `glab issue view <n> --comments` |
| File | `glab issue create --title "<title>" --description "<body>"` |
| Comment | `glab issue note <n> --message "<body>"` |
| Label | `glab issue update <n> --label <label>` (`--unlabel` to drop) |
| Close | post the reason as a note, then `glab issue close <n>` |

## Star chart operations

- **Star chart**: an issue labelled `starchart:chart`.
- **Ticket**: an issue whose description starts with `Part of #<chart>`, labelled `starchart:<kind>` unless it is a star.
- **Blocking**: a native blocking link, added with the note `/blocked_by #<blocker>`. Where the plan lacks blocking links, a `Blocked by: #<n>` line tops the description.
- **Frontier**: the chart's open children with no assignee and no open blocker (`glab api projects/:id/issues/:iid/links`).
- **Chart**: a Mermaid block under `## Chart`. GitLab draws it.
- **Claim**: `glab issue update <n> --assignee @me`, before any other write.
