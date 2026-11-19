#!/usr/bin/env bash
# SessionStart hook: a reporter's deadline is never missed in silence. For
# each draft advisory of this repo the security kit keeps, it names the ones
# due within a week whose fix has not shipped, and the ones past their
# deadline and still unpublished. It publishes nothing: that waits on the
# user's own word (advisory-guard). A draft further off says nothing.
cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null && git rev-parse --show-toplevel >/dev/null 2>&1 || exit 0
# shellcheck source=../skills/shipping/security/scripts/kit.sh
. "$(dirname "$0")/../skills/shipping/security/scripts/kit.sh"
today=$(date +%F); soon=$(date -d '+7 days' +%F)
for state in "$store"/*/state.json; do
  jq -r --arg today "$today" --arg soon "$soon" '
    select(.state == "draft" and (.deadline // "") != "")
    | if .deadline < $today then
        "Security advisory \(.id): the reporter'"'"'s deadline passed on \(.deadline), and it is still unpublished. Nothing publishes without the user'"'"'s word: ask them whether to publish it now."
      elif .deadline <= $soon and (.fixed // "") == "" then
        "Security advisory \(.id) is due on \(.deadline), and its fix has not shipped."
      else empty end' "$state" 2>/dev/null
done
exit 0 # mutant-ok delete: a no-op in its place also ends the script with status 0
