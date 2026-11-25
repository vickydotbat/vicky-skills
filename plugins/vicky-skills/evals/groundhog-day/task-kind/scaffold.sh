#!/usr/bin/env bash
# A small app whose tracker is a folder of notes with a bug kind. The task
# asked for is not a bug, so the note must not take that kind.
set -eu
git init -q -b main .
mkdir -p docs/agents tickets src
cat > docs/agents/issue-tracker.md <<'MD'
# Tickets: notes

Tickets are Markdown notes in `tickets/`, one note per ticket, named `<n>-<title>.md`.

| Action | How |
| --- | --- |
| File | Write a new note in `tickets/`. A bug report's note starts with the line `kind: bug`. |
| Comment | Append `- <text>` under `## Comments` in the note. |
| Find | `grep -ril '<text>' tickets/` |
MD
cat > tickets/14-settings-language.md <<'MD'
# Settings page forgets the language you picked

## Comments
MD
cat > src/settings.js <<'JS'
export function save(form, store) {
  if (!form.displayName) return;
  store.put("displayName", form.displayName);
  store.put("language", form.language);
}
JS
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
