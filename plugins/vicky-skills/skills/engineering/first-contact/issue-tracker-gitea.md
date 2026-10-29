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

## Wayfinding operations

- **Map**: an issue labelled `wayfinder:map`.
- **Ticket**: an issue whose body starts with `Part of #<map>`, labelled `wayfinder:<kind>` for a decision ticket. Gitea has no sub-issues, so the map's body lists its tickets.
- **Blocking**: Gitea's issue dependencies. Add one with `tea api -X POST repos/<owner>/<repo>/issues/<child>/dependencies -d '{"owner":"<owner>","repo":"<repo>","index":<blocker>}' </dev/null`. List a ticket's blockers with a GET on the same path.
- **Frontier**: the map's open tickets with no assignee and no open blocker.
- **Claim**: `tea issues edit <n> --add-assignees <you> </dev/null`, before any other write.
