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

## Waiting work

A waiting ticket can't go on until the thing its `Waits on:` line names is done. It waits on you when that line names you: your decision, answer or merge. Every agent acts as your account, so the assignee can't tell your move from an agent's. `loose-ends` parks one, and `gamma-shift` works through them.

- **List waiting tickets**: `glab issue list --search "Waits on:" --in description`.
- **List tickets waiting on you**: `glab issue list --search "Waits on:" --in description`, keeping each whose `Waits on:` line names you: your decision, answer or merge.
- **Move a ticket to <state>**: GitLab has only opened and closed. Started is open with a branch or draft merge request that names it; not-started is open with none. Done is `glab issue close <n>`, and back from done is `glab issue reopen <n>`.
- **List items created or changed since <time>**: `glab api "projects/:fullpath/issues?updated_after=<time>&order_by=updated_at"`. An item whose `created_at` is at or after `<time>` is new, any other is edited. Show at most five, then a count of the rest.
- **Park a ticket**: `glab issue update <n> --assignee @me`, then add a `Waits on: <who or what>` line to the description. GitLab has no not-started state: an open, assigned ticket with that line is waiting.
- **Claim a waiting ticket**: delete its `Waits on:` line, before any other write.

## Ticket drift

Ticket drift: on

Change `on` to `off` to stop the `ticket-drift` check in this repo.
