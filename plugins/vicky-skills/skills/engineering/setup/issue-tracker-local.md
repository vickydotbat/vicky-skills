# Tickets: local files

Tickets are Markdown files under `.scratch/`, one folder per effort. Comments go at the bottom of a ticket under `## Comments`.

## Wayfinding operations

- **Map**: `.scratch/<effort>/map.md`.
- **Ticket**: `.scratch/<effort>/issues/NN-<slug>.md`, numbered from `01`. A `Kind:` line holds the decision kind, and a `Status:` line holds `open`, `claimed` or `done`.
- **Blocking**: a `Blocked by: NN, NN` line near the top. A ticket is unblocked when every file it lists is `done`.
- **Frontier**: the open, unblocked tickets, lowest number first.
- **Claim**: set `Status: claimed` and save, before any other work.
- **Close**: add the answer under `## Answer` and set `Status: done`.
