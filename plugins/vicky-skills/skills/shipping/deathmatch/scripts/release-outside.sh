#!/usr/bin/env bash
# release-outside.sh [session id]: lifts mark-outside.sh's mark, so
# outside-text-guard lets the session write to the forge again. The user types
# it as a `!` command, which runs outside the hooks; the guard refuses the
# agent's own call. The session defaults to CLAUDE_CODE_SESSION_ID. A `!`
# shell may not carry CLAUDE_PLUGIN_DATA, so every plugin data folder under
# the Claude config folder is searched for the mark.
set -u
sid=${1:-${CLAUDE_CODE_SESSION_ID:-}}
[ -n "$sid" ] || { echo "usage: release-outside.sh <session id>" >&2; exit 2; }
case $sid in */* | .*) echo "release-outside: not a session id: $sid" >&2; exit 2 ;; esac
found=0
for mark in "${CLAUDE_PLUGIN_DATA:-/nonexistent}/outside-read/$sid" "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"/plugins/data/*/outside-read/"$sid"; do
  [ -e "$mark" ] || continue
  rm -f -- "$mark" && found=1
done
if [ "$found" = 1 ]; then echo "release-outside: session $sid may write to the forge again"; else echo "release-outside: session $sid holds no mark"; fi
