#!/usr/bin/env bash
# Opens a draft file or a checklist as a page in the user's browser and waits
# for Done. It runs open-draft.sh with the page in the editor's
# place, so the draft lock and the approval grants work the same way. With no
# browser on the machine (no display), the file opens in the user's editor.
# Usage: open-page.sh <file.md>
# shortcut: open-draft.sh splits VISUAL on spaces, so a plugin folder whose
# path holds a space falls back to the editor; pass the page as an argument
# array if that ever happens.
here=$(cd "$(dirname "$0")" && pwd)
if { [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ] || [ "$(uname)" = Darwin ]; } && [[ $here != *" "* ]]; then
  export VISUAL="python3 -I $here/page.py"
fi
exec bash "$here/open-draft.sh" "$@"
