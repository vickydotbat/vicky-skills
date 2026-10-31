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

A waiting ticket is assigned to the user and can't go on until the thing its `Waits on:` line names is done. `loose-ends` parks one, and `gamma-shift` works through them.

- **List tickets waiting on you**: `grep -l '^Status: waiting' .scratch/*/issues/*.md`.
- **Park a ticket**: set `Status: waiting` and add a `Waits on: <who or what>` line.
- **Claim a waiting ticket**: set `Status: claimed`, before any other work.

## Ticket drift

Ticket drift: on

Change `on` to `off` to stop the `ticket-drift` check in this repo.
