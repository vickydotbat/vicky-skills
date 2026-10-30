# Tickets: Gitea

Tickets are Gitea issues in this repo. Work them with `tea`, which reads the repo from `git remote -v`. End every `tea` call with `</dev/null`: without it `tea` can wait on a prompt, a write may land anyway, and a retry posts twice. Read the thread before any retry.

| Action | Command |
| --- | --- |
| Read, whole | `tea issues <n> --comments </dev/null` |
| File | `tea issues create --title "<title>" --description "$(cat <file>)" </dev/null` |
| Comment | `tea comment <n> "$(cat <file>)" </dev/null` |
| Label | `tea issues edit <n> --add-labels <label> </dev/null` |
| Close | comment the reason, then `tea issues close <n> </dev/null` |
| Raw API | `tea api -X <method> repos/<owner>/<repo>/<path> -d '<json>' </dev/null` |

## Star chart operations

- **Star chart**: an issue labelled `starchart:chart`.
- **Ticket**: an issue whose body starts with `Part of #<chart>`, labelled `starchart:<kind>` unless it is a star. Gitea has no sub-issues, so the chart's body lists its tickets.
- **Blocking**: Gitea's issue dependencies. Add one with `tea api -X POST repos/<owner>/<repo>/issues/<child>/dependencies -d '{"owner":"<owner>","repo":"<repo>","index":<blocker>}' </dev/null`. List a ticket's blockers with a GET on the same path.
- **Frontier**: the chart's open tickets with no assignee and no open blocker.
- **Chart**: a Mermaid block under `## Chart`. Gitea draws it, unless the server swaps in its own Markdown renderer.
- **Claim**: `tea issues edit <n> --add-assignees <you> </dev/null`, before any other write.

## Waiting work

A waiting ticket is assigned to the user and can't go on until the thing its `Waits on:` line names is done. `loose-ends` parks one, and `gamma-shift` works through them.

- **List tickets waiting on you**: `tea issues list --state open --assignee <you> --keyword "Waits on:" --fields index,title,body </dev/null`.
- **Park a ticket**: `tea issues edit <n> --add-assignees <you> </dev/null`, then add a `Waits on: <who or what>` line to the body. Gitea has no not-started state: an open, assigned ticket with that line is waiting.
- **Claim a waiting ticket**: delete its `Waits on:` line, before any other write.
