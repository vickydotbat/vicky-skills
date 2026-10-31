#!/usr/bin/env bash
# Opens a draft file or a checklist as a page in the user's browser and waits
# for Done. It runs red-pen's open-draft.sh with the page in the editor's
# place, so the draft lock and the approval grants work the same way. With no
# browser on the machine (no display), the file opens in the user's editor.
# Usage: open-page.sh <file.md>
set -u
[ $# = 1 ] || { echo "usage: open-page.sh <file.md>" >&2; exit 2; }
here=$(cd "$(dirname "$0")" && pwd)
open_draft="$here/../../red-pen/scripts/open-draft.sh"
if [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ] || [ "$(uname)" = Darwin ]; then
  VISUAL="python3 -I $here/page.py" exec bash "$open_draft" "$1"
fi
exec bash "$open_draft" "$1"
