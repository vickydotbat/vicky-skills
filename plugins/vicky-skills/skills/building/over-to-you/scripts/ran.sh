#!/usr/bin/env bash
# Runs one over-to-you check the agent's own way and keeps a receipt of the run.
# The way is the agent's choice: a test harness, a headless client, a browser
# script, a seed command. checklist.py refuses an item whose receipt is missing,
# failed, or names a commit other than HEAD, so no sitting opens on a check the
# agent never ran.
# Usage: ran.sh <id> <command> [args...]
#   <id>: the item's receipt name, letters, digits, dot, dash or underscore.
# The receipt is <scratch>/over-to-you-receipts/<id>.json, where <scratch> is
# the session folder, ${TMPDIR:-/tmp}/$CLAUDE_CODE_SESSION_ID. The command's
# output passes through, and ran.sh exits with the command's status.
# A hung command is stopped at RAN_TIMEOUT seconds, 600 by default.
set -u
[ $# -ge 2 ] || { echo "usage: ran.sh <id> <command> [args...]" >&2; exit 2; }
id=$1; shift
[[ $id =~ ^[A-Za-z0-9._-]+$ ]] || { echo "ran.sh: the id '$id' holds a character outside letters, digits, dot, dash and underscore" >&2; exit 2; }
[ -n "${CLAUDE_CODE_SESSION_ID:-}" ] || { echo "ran.sh: CLAUDE_CODE_SESSION_ID is unset, so there is no session folder for the receipt" >&2; exit 2; }
command -v jq >/dev/null || { echo "ran.sh: jq is missing, so no receipt can be written" >&2; exit 2; }
dir="${TMPDIR:-/tmp}/$CLAUDE_CODE_SESSION_ID/over-to-you-receipts"
mkdir -p "$dir" || exit 2
log=$(mktemp "$dir/.$id.XXXXXX") || exit 2 # mutant-ok: mkdir -p made the folder a line above, so mktemp fails here only on a full disk
trap 'rm -f "$log"' EXIT
at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
timeout "${RAN_TIMEOUT:-600}" "$@" 2>&1 | tee "$log"
status=${PIPESTATUS[0]}
head=$(git rev-parse HEAD 2>/dev/null || true)
jq -n --arg id "$id" --arg command "$*" --arg at "$at" --arg head "$head" --arg cwd "$PWD" --argjson exit "$status" \
  --arg tail "$(tail -n 20 "$log")" '{id:$id, command:$command, exit:$exit, at:$at, head:$head, cwd:$cwd, tail:$tail}' > "$dir/$id.json"
echo "ran.sh: receipt $dir/$id.json, exit $status" >&2
exit "$status"
