#!/usr/bin/env bash
# A small app whose tracker is a folder of notes. One note already covers dark
# mode, and the code already has a theme switch the brief should reuse.
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
# Let players pick a light or dark theme

The settings page gets a theme choice. Decided: the choice is saved per account, not per device.

## Comments
- The theme switch in src/theme.js already flips the page colours.
MD
cat > tickets/14-language-picker.md <<'MD'
# Language picker on the settings page

## Comments
MD
cat > src/theme.js <<'JS'
export function setTheme(name) {
  document.body.dataset.theme = name === "dark" ? "dark" : "light";
}
JS
cat > src/settings.js <<'JS'
import { setTheme } from "./theme.js";
export function renderSettings(root) {
  root.innerHTML = "<h1>Settings</h1>";
}
JS
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
