#!/usr/bin/env bash
# SessionStart hook (startup only): reminds the agent of the items in the
# repo's .todo file, one short list too small for a ticket. Silent when the
# file is missing or empty, and when docs/agents says "Todo file: off".
set -u
cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0 # mutant-ok: the project folder exists whenever Claude Code starts a session in it
grep -qs '^Todo file: off' docs/agents/*.md && exit 0
items=$(sed '/^# springboard start/,/^# springboard end/d' .todo 2>/dev/null | grep -v '^[[:space:]]*$') || exit 0
echo "This repo's .todo file lists small items to do:"
printf '%s\n' "$items" | sed 's/^/- /'
echo "Delete an item's line from .todo once it is done."
