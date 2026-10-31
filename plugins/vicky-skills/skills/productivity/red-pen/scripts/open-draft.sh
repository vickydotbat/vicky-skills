#!/usr/bin/env bash
# Opens a draft in the user's editor and waits for the close. While it is
# open, a lock in the current checkout's git folder holds the editor's
# process id, and the draft-lock hook refuses edits to the checkout. A section
# whose text the user changed grants the file on its location line to the
# approved-spec guard, which reads it for approved tests only.
# Usage: open-draft.sh <draft file>
set -u
[ $# = 1 ] || { echo "usage: open-draft.sh <draft file>" >&2; exit 2; }
editor=${VISUAL:-${EDITOR:-}}
[ -n "$editor" ] || { echo "open-draft: set VISUAL or EDITOR, or tell the user the draft's path" >&2; exit 2; }
lock=""
if gitdir=$(git rev-parse --absolute-git-dir 2>/dev/null); then lock="$gitdir/red-pen-open"; fi
# shellcheck disable=SC2086 # the editor variable holds a command and its flags
before=$(cat "$1" 2>/dev/null)
$editor "$1" & pid=$!
[ -n "$lock" ] && printf '%s\n%s\n' "$pid" "$1" > "$lock"
trap '[ -n "$lock" ] && rm -f "$lock"' EXIT
wait "$pid"
[ -n "$lock" ] && [ -f "$1" ] || exit 0
# Each section on one line: its location's path, a tab, then its text.
sections() { awk '/^## /{if (loc != "") print loc "\t" body; loc=""; body=""; getline loc; sub(/:.*/, "", loc); next} {body = body $0 "\034"} END {if (loc != "") print loc "\t" body}'; }
grep -vxF -f <(sections <<<"$before") <(sections < "$1") | cut -f1 >> "$(dirname "$lock")/approved-spec-grants" 2>/dev/null
exit 0
