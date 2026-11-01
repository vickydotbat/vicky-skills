# Tickets: local files

Tickets are Markdown files under `.scratch/`, one folder per effort. Comments go at the bottom of a ticket under `## Comments`.

## Star chart operations

- **Star chart**: `.scratch/<effort>/chart.md`.
- **Ticket**: `.scratch/<effort>/issues/NN-<slug>.md`, numbered from `01`. A `Kind:` line holds the kind (`anomaly`, `away-team`, `probe`, `task` or `star`), and a `Status:` line holds `open`, `claimed`, `waiting` or `done`.
- **Blocking**: a `Blocked by: NN, NN` line near the top. A ticket is unblocked when every file it lists is `done`.
- **Frontier**: the open, unblocked tickets, lowest number first.
- **Chart**: a Mermaid block under `## Chart` in `chart.md`.
- **Claim**: set `Status: claimed` and save, before any other work.
- **Close**: add the answer under `## Answer` and set `Status: done`.

## Waiting work

A waiting ticket can't go on until the thing its `Waits on:` line names is done. It waits on you when that line names you: your decision, answer or merge. Every agent acts as your account, so the assignee can't tell your move from an agent's. `loose-ends` parks one, and `gamma-shift` works through them.

- **List waiting tickets**: `grep -l '^Waits on:' .scratch/*/issues/*.md`.
- **List tickets waiting on you**: `grep -l '^Waits on:' .scratch/*/issues/*.md`, keeping each ticket whose `Waits on:` line names you: your decision, answer or merge.
- **Move a ticket to <state>**: set the `Status:` line to `open` for not-started, `claimed` for started, `waiting` when parked or `done`.
- **List items created or changed since <time>**: `find .scratch -path '*/issues/*.md' -newermt '<time>'`. A ticket that `git log --diff-filter=A --since=<time>` adds is new, any other is edited. Show at most five, then a count of the rest.
- **Park a ticket**: set `Status: waiting` and add a `Waits on: <who or what>` line.
- **Claim a waiting ticket**: set `Status: claimed`, before any other work.

## Ticket drift

Ticket drift: on

Change `on` to `off` to stop the `ticket-drift` check in this repo.
