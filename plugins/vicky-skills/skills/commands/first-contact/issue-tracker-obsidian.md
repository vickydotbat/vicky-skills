# Tickets: Obsidian

Tickets are notes in the user's Obsidian vault, in `<vault>/<Project>/`, one note per ticket. Name a new note `YYYYMMDDHHMMSS <Title>.md`. The frontmatter holds the fields below, and comments go at the bottom under `## Comments`, newest last. A note is never deleted: a ticket ends as `status: done`.

```yaml
---
kind: anomaly        # chart, anomaly, away-team, probe, task or star
status: open         # open, claimed, waiting or done
closed:              # the date it was set done, YYYY-MM-DD
parent: "[[<chart note name>]]"
blocked_by: ["[[<blocker note title>]]"]
labels: []           # a chart ready to warp holds starchart:afk
---
```

| Action | How |
| --- | --- |
| Read, whole | Read the note, frontmatter and `## Comments` included. |
| File | Write a new note in `<vault>/<Project>/` with the frontmatter above. |
| Comment | Append `- YYYY-MM-DD: <text>` under `## Comments`. |
| Find | `grep -l '<text>' "<vault>/<Project>/"*.md` |
| Close | Comment the reason, then set `status: done` and `closed: YYYY-MM-DD`. |

## Star chart operations

- **Star chart**: a note named `YYYYMMDDHHMMSS Star Chart - <effort>.md` with `kind: chart`. Obsidian refuses a colon in a note name, and a link names the whole note, timestamp included.
- **Ticket**: a note whose `parent` links the chart. A star has `kind: star`.
- **List a chart's tickets**: `grep -l 'parent: "\[\[[0-9]* Star Chart - <effort>\]\]"' "<vault>/<Project>/"*.md`
- **Blocking**: the `blocked_by` links. A ticket is unblocked when every note it links is `status: done`.
- **Frontier**: the chart's tickets with `status: open` and no blocker still open.
- **List charts ready to warp**: `grep -l '^labels:.*starchart:afk' "<vault>/<Project>/"*.md`, keeping notes with `kind: chart` and `status: open`.
- **Chart**: a Mermaid block under `## Chart` in the chart note. Obsidian draws it.
- **Claim**: set `status: claimed` and save, before any other work.

## Waiting work

A waiting ticket can't go on until the thing its `Waits on:` line names is done. It waits on you when that line names you: your decision, answer or merge. Every agent acts as your account, so the assignee can't tell your move from an agent's. `make-it-so`'s SETTLE.md parks one, and `gamma-shift` works through them.

- **List waiting tickets**: `grep -l '^Waits on:' "<vault>/<Project>/"*.md`.
- **List tickets waiting on you**: `grep -l '^Waits on:' "<vault>/<Project>/"*.md`, keeping each note whose `Waits on:` line names you: your decision, answer or merge.
- **Move a ticket to <state>**: set `status:` in the frontmatter to `open` for not-started, `claimed` for started, `waiting` when parked or `done`.
- **List notes off the tracker**: `bash ${CLAUDE_PLUGIN_ROOT}/skills/housekeeping/summit/scripts/tracker-status.sh "<vault>/<Project>/"`. It lists each note with no `status:` in its frontmatter, a status outside the four above, or no timestamp in its name. The "since" operations miss such a note, so give each one its status from its own text (a note with no word of being done stays `open`) and its timestamped name, stamped with the note's own creation time so it never counts as new, and update the links to a renamed note.
- **List items created or changed since <time>**: `find "<vault>/<Project>/" -name '*.md' -newermt '<time>'`. A note whose name's timestamp is at or after `<time>` is new, any other is edited. Show at most five, then a count of the rest.
- **List items closed since <time>**: `find "<vault>/<Project>/" -name '*.md' -exec grep -l '^status: done' {} +`, keeping each note whose `closed:` date is on or after `<time>`'s date, and each note with no `closed:` date that changed since `<time>`. A later edit to a closed note never counts it again. Give the count.

Summit count: `bash "$CLAUDE_PLUGIN_ROOT/scripts/summit-obsidian.sh" "$CLAUDE_PLUGIN_OPTION_OBSIDIAN_VAULT/<Project>"`

The session-start summit runs this line with no agent: it prints the opened and closed counts since `$SUMMIT_SINCE`. Delete it to switch the summit off in this repo. The vault folder comes from the plugin's `obsidian_vault` setting.

- **Park a ticket**: set `status: waiting` and add a `Waits on: <who or what>` line under the frontmatter.
- **Claim a waiting ticket**: set `status: claimed` and delete its `Waits on:` line, before any other work.

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
