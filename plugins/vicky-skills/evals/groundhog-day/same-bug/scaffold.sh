#!/usr/bin/env bash
# A tracker of notes where ticket 9 already covers Save failing on an empty
# display name, under other words.
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
cat > tickets/9-blank-name-blocks-saving.md <<'MD'
# Settings can't be saved with a blank name

Status: open. Pressing Save on the settings page with no display name keeps every setting as it was.

## Comments
MD
cat > src/settings.js <<'JS'
export function save(form, store) {
  if (!form.displayName) return;
  store.put("displayName", form.displayName);
}
JS
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
