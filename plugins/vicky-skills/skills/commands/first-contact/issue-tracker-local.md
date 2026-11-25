# Tickets: local files

Tickets are Markdown files under `.scratch/`, one folder per effort. Comments go at the bottom of a ticket under `## Comments`.

## Star chart operations

- **Star chart**: `.scratch/<effort>/chart.md`.
- **Ticket**: `.scratch/<effort>/issues/NN-<slug>.md`, numbered from `01`. A `Kind:` line holds the kind (`anomaly`, `away-team`, `probe`, `task` or `star`), and a `Status:` line holds `open`, `claimed`, `waiting` or `done`.
- **Blocking**: a `Blocked by: NN, NN` line near the top. A ticket is unblocked when every file it lists is `done`.
- **Frontier**: the open, unblocked tickets, lowest number first.
- **List charts ready to warp**: `grep -l '^Labels:.*starchart:afk' .scratch/*/chart.md`, keeping the open charts, those without `Status: done`. A chart's `Labels:` line holds its labels.
- **Chart**: a Mermaid block under `## Chart` in `chart.md`.
- **Claim**: set `Status: claimed` and save, before any other work.
- **Close**: add the answer under `## Answer` and set `Status: done`.

## Waiting work

A waiting ticket can't go on until the thing its `Waits on:` line names is done. It waits on you when that line names you: your decision, answer or merge. Every agent acts as your account, so the assignee can't tell your move from an agent's. `make-it-so`'s SETTLE.md parks one, and `gamma-shift` works through them.

- **List waiting tickets**: `grep -l '^Waits on:' .scratch/*/issues/*.md`.
- **List tickets waiting on you**: `grep -l '^Waits on:' .scratch/*/issues/*.md`, keeping each ticket whose `Waits on:` line names you: your decision, answer or merge.
- **Move a ticket to <state>**: set the `Status:` line to `open` for not-started, `claimed` for started, `waiting` when parked or `done`.
- **List items created or changed since <time>**: `find .scratch -path '*/issues/*.md' -newermt '<time>'`. A ticket that `git log --diff-filter=A --since=<time>` adds is new, any other is edited. Show at most five, then a count of the rest.
- **List items closed since <time>**: `git log --since=<time> -G '^Status: done' --name-only --format= -- .scratch | sort -u`, keeping each ticket whose `Status:` line now reads `done`. Give the count.

Summit count: `echo "$(git log --since="$SUMMIT_SINCE" --diff-filter=A --name-only --format= -- .scratch | grep -c "/issues/.*\.md$") $(git log --since="$SUMMIT_SINCE" -S "Status: done" --name-only --format= -- .scratch | sort -u | grep -c "/issues/.*\.md$")"`

The session-start summit runs this line with no agent: it prints the opened and closed counts since `$SUMMIT_SINCE`. Delete it to switch the summit off in this repo.

- **Park a ticket**: set `Status: waiting` and add a `Waits on: <who or what>` line.
- **Claim a waiting ticket**: set `Status: claimed` and delete its `Waits on:` line, before any other work.

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
