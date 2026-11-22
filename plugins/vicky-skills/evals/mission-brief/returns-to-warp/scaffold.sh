#!/usr/bin/env bash
# A small app whose tracker is a folder of notes, with a course in flight:
# tickets 14 and 15 are still left to fly.
set -eu
git init -q -b main .
mkdir -p docs/agents tickets src
cat > docs/agents/issue-tracker.md <<'MD'
# Tickets: notes

Tickets are Markdown notes in `tickets/`, one note per ticket, named `<n>-<title>.md`.

| Action | How |
| --- | --- |
| File | Write a new note in `tickets/`. |
| Comment | Append `- <text>` under `## Comments` in the note. |
| Find | `grep -ril '<text>' tickets/` |
MD
cat > tickets/12-theme-choice.md <<'MD'
# Let players pick a light or dark theme (done)
MD
cat > tickets/14-language-picker.md <<'MD'
# Language picker on the settings page

Star. Examples: approved. Left on the course.
MD
cat > tickets/15-font-size.md <<'MD'
# Font size setting

Star. Examples: approved. Left on the course.
MD
echo 'export function setTheme(name) { document.body.dataset.theme = name; }' > src/theme.js
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
