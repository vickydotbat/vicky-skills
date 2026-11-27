# Tickets: Backlog.md

Tickets are tasks in a Backlog.md project, a folder of Markdown files the `backlog` CLI keeps. The folder lives outside every checkout, so ticket text never lands in the repo:

Backlog folder: <folder>

Every command below runs with `BACKLOG_CWD=<folder>` set, from any directory. Change a task only with a `backlog` command, never by editing its file: the CLI keeps the file's fields, IDs and links in step.

Setup, once: `mkdir -p <folder> && cd <folder> && backlog init "<Project>" --no-git --defaults`, then set `statuses: ["Open", "Claimed", "Waiting", "Done"]` and `default_status: "Open"` in `<folder>/backlog/config.yml`. The CLI has no command for the status list.

A ticket's kind is a label: `chart`, `anomaly`, `away-team`, `probe`, `task` or `star`.

| Action | How |
| --- | --- |
| Read, whole | `backlog task <id> --plain` |
| File | `backlog task create "<title>" -d "<body>" -l <kind> --plain` |
| Comment | `backlog task edit <id> --comment "<text>" --comment-author <who>` |
| Find | `backlog search "<text>" --plain` |
| Close | Comment the reason, then `backlog task edit <id> -s Done`. |

## Star chart operations

- **Star chart**: a task labelled `chart`, whose description holds the chart's body.
- **Ticket**: a subtask of the chart: `backlog task create "<title>" -p <chart id> -l <kind> --plain`. A star has the label `star`.
- **List a chart's tickets**: `backlog task list --parent <chart id> --plain`
- **Blocking**: dependencies, set with `--dep <id>,<id>` on create or edit. A ticket is unblocked when every task it depends on is Done.
- **Frontier**: `backlog task list --parent <chart id> -s Open --json`, keeping the tasks whose `isReady` is true.
- **List charts ready to warp**: `backlog task list --labels chart,starchart:afk -s Open --plain`.
- **Chart**: a Mermaid block under `## Chart` in the chart task's description.
- **Claim**: `backlog task edit <id> -s Claimed`, before any other work.

## Waiting work

A waiting ticket can't go on until the thing its `Waits on:` line names is done. It waits on you when that line names you: your decision, answer or merge. Every agent acts as your account, so the assignee can't tell your move from an agent's. `make-it-so`'s SETTLE.md parks one, and `gamma-shift` works through them.

- **List waiting tickets**: `backlog task list -s Waiting --plain`, then read each one whole for its `Waits on:` line.
- **List tickets waiting on you**: the waiting tickets whose `Waits on:` line names you: your decision, answer or merge.
- **Move a ticket to <state>**: `backlog task edit <id> -s <state>`, with `Open` for not-started, `Claimed` for started, `Waiting` when parked or `Done`.
- **List items created or changed since <time>**: `backlog task list --json`, keeping each task whose `createdAt` or `updatedAt` is at or after `<time>`. A task never edited since it was filed has `updatedAt: null`, so its `createdAt` decides. One whose `createdAt` is at or after `<time>` is new, any other is edited. Show at most five, then a count of the rest.
- **List items closed since <time>**: `backlog task list -s Done --json`, keeping each task whose `updatedAt` is at or after `<time>`. Give the count.
- **Park a ticket**: `backlog task edit <id> -s Waiting --append-notes "Waits on: <who or what>"`.
- **Claim a waiting ticket**: `backlog task edit <id> -s Claimed --notes "<the notes without the Waits on: line>"`, before any other work.

## Ticket drift

Ticket drift: on

Change `on` to `off` to stop the `ticket-drift` check in this repo.

## Pull request bodies

PR template: on

Change `on` to `off` to stop `pr-guard` refusing a pull request body that lacks a section the repo's pull request template asks for, or `ship-it`'s Status, Summary, Proof and Risk when it has none, in this repo.

Seed PR template: on

Change `on` to `off` to stop `first-contact` writing a pull request template into this repo.

PR drafts: on

Change `on` to `off` to stop `draft-guard` refusing a pull request opened ready for review, or marked ready before `make-it-so` starts, in this repo.

## Pull request claims

Claim voice: Borg

Change `Borg` to `plain` to have `assimilate` claim another person's pull request in this repo without its Borg line.

## Review cause

Review cause: on

Change `on` to `off` to stop `deathmatch` running its Cause opponent for a branch that claims a fix in this repo.

## Familiar

Familiar: on

Change `on` to `off` to stop `familiar` watching sessions in this repo.
