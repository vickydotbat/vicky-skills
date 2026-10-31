#!/usr/bin/env bash
# Opens a draft in the user's editor and waits for the close. While it is
# open, a lock in the current checkout's git folder holds the editor's
# process id, and the draft-lock hook refuses edits to the checkout. A section
# whose text the user changed grants the file on its location line to the
# approved-spec guard, which reads it for approved tests only.
# open-page.sh runs this script with its page as the editor. The editor's exit
# status is this script's, so a page nobody answered reads as no answer.
# Usage: open-draft.sh <draft file>
set -u
[ $# = 1 ] || { echo "usage: open-draft.sh <draft file>" >&2; exit 2; }
# shellcheck source=../../../../scripts/approved-spec.sh
. "$(dirname "$0")/../../../../scripts/approved-spec.sh"
# A section for a file that holds approved examples reaches the editor only in a form a tick can grant:
# its location is exactly <path>:<line or "new">, and it holds an approve box, added here when missing.
top=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
sections_for_approved() { # prints each approved-examples section's location, a tab, then 1 when it has a box
  awk '/^## /{if (loc != "") print loc "\t" box; loc=""; box=0; while ((getline loc) > 0 && loc == "") continue; next} /^- \[[ xX]\] approve/{box=1} END {if (loc != "") print loc "\t" box}' "$1" |
    while IFS=$'\t' read -r loc box; do approved "$top/${loc%%[:, ]*}" && printf '%s\t%s\n' "$loc" "$box"; done
}
if [ -f "$1" ]; then
  found=$(sections_for_approved "$1")
  bad=$(cut -f1 <<<"$found" | grep -vE '^[^[:space:]:,]+:([0-9]+|new)$')
  [ -z "$bad" ] || { printf 'open-draft: write each approved-examples location as <path>:<line or new>:\n%s\n' "$bad" >&2; exit 2; }
  while IFS=$'\t' read -r loc box; do
    [ "$box" = 0 ] && awk -v loc="$loc" '{print} $0 == loc && !done {print "- [ ] approve"; done=1}' "$1" > "$1.tmp" && mv "$1.tmp" "$1"
  done <<<"$found"
fi
editor=${VISUAL:-${EDITOR:-}}
[ -n "$editor" ] || { echo "open-draft: set VISUAL or EDITOR, or tell the user the draft's path" >&2; exit 2; }
lock=""
if gitdir=$(git rev-parse --absolute-git-dir 2>/dev/null); then lock="$gitdir/red-pen-open"; fi
# shellcheck disable=SC2086 # the editor variable holds a command and its flags
before=$(cat "$1" 2>/dev/null)
$editor "$1" & pid=$!
[ -n "$lock" ] && printf '%s\n%s\n' "$pid" "$1" > "$lock"
trap '[ -n "$lock" ] && rm -f "$lock"' EXIT
wait "$pid"; status=$?
[ -n "$lock" ] && [ -f "$1" ] || exit "$status"
# Each section on one line: its location's path, a tab, then its text. The
# location is the first line after the heading that isn't blank, since an
# editor may save a blank line under each heading. An unticked approve box is
# no change, so the one added above grants nothing by itself, and neither is a
# blank line, which the page moves when it adds its closing comment. A section whose
# location isn't <path>:<line or new>, such as the page's closing comment, grants nothing.
sections() { awk '/^## /{if (loc != "") print loc "\t" body; loc=""; body=""; while ((getline loc) > 0 && loc == "") continue; if (loc !~ /^[^[:space:]:,]+:([0-9]+|new)$/) loc = ""; sub(/:.*/, "", loc); next} /^- \[ \] approve$/ || /^$/{next} {body = body $0 "\034"} END {if (loc != "") print loc "\t" body}'; }
grep -vxF -f <(sections <<<"$before") <(sections < "$1") | cut -f1 >> "$(dirname "$lock")/approved-spec-grants" 2>/dev/null
exit "$status"
