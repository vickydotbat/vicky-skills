# Tickets: Obsidian

Tickets are notes in the user's Obsidian vault, in `<vault>/<Project>/`, one note per ticket. Name a new note `YYYYMMDDHHMMSS <Title>.md`. The frontmatter holds the fields below, and comments go at the bottom under `## Comments`, newest last. A note is never deleted: a ticket ends as `status: done`.

```yaml
---
kind: anomaly        # chart, anomaly, away-team, probe, task or star
status: open         # open, claimed, waiting or done
parent: "[[<chart note name>]]"
blocked_by: ["[[<blocker note title>]]"]
---
```

| Action | How |
| --- | --- |
| Read, whole | Read the note, frontmatter and `## Comments` included. |
| File | Write a new note in `<vault>/<Project>/` with the frontmatter above. |
| Comment | Append `- YYYY-MM-DD: <text>` under `## Comments`. |
| Find | `grep -l '<text>' "<vault>/<Project>/"*.md` |
| Close | Comment the reason, then set `status: done`. |

## Star chart operations

- **Star chart**: a note named `YYYYMMDDHHMMSS Star Chart - <effort>.md` with `kind: chart`. Obsidian refuses a colon in a note name, and a link names the whole note, timestamp included.
- **Ticket**: a note whose `parent` links the chart. A star has `kind: star`.
- **List a chart's tickets**: `grep -l 'parent: "\[\[[0-9]* Star Chart - <effort>\]\]"' "<vault>/<Project>/"*.md`
- **Blocking**: the `blocked_by` links. A ticket is unblocked when every note it links is `status: done`.
- **Frontier**: the chart's tickets with `status: open` and no blocker still open.
- **Chart**: a Mermaid block under `## Chart` in the chart note. Obsidian draws it.
- **Claim**: set `status: claimed` and save, before any other work.

## Waiting work

A waiting ticket is assigned to the user and can't go on until the thing its `Waits on:` line names is done. `loose-ends` parks one, and `gamma-shift` works through them.

- **List tickets waiting on you**: `grep -l '^status: waiting' "<vault>/<Project>/"*.md`.
- **Park a ticket**: set `status: waiting` and add a `Waits on: <who or what>` line under the frontmatter.
- **Claim a waiting ticket**: set `status: claimed`, before any other work.
