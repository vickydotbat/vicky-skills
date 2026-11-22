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
# RAN_HOLD=<seconds> runs a passing command again after that wait, for a
# liveness check that must show a server stayed up.
# A hung command is stopped at RAN_TIMEOUT seconds, 600 by default, and
# killed RAN_GRACE seconds later, 5 by default, when it ignores the stop.
# Its output goes through dd into a file, which stops at RAN_MAX_BYTES,
# 50 MiB by default. The cap sits on the pipe, never on the command: a ulimit
# -f is inherited, and it killed every server a check started once that
# server's own files passed the cap. Past the cap the reader drains the rest to
# /dev/null and is never stopped, since a writer whose pipe closes dies of
# SIGPIPE: a child the command leaves running keeps a live sink until it ends.
# The output is printed once the command ends.
set -u
[ $# -ge 2 ] || { echo "usage: ran.sh <id> <command> [args...]" >&2; exit 2; }
id=$1; shift
[[ $id =~ ^[A-Za-z0-9._-]+$ ]] || { echo "ran.sh: the id '$id' holds a character outside letters, digits, dot, dash and underscore" >&2; exit 2; }
[ -n "${CLAUDE_CODE_SESSION_ID:-}" ] || { echo "ran.sh: CLAUDE_CODE_SESSION_ID is unset, so there is no session folder for the receipt" >&2; exit 2; }
command -v python3 >/dev/null || { echo "ran.sh: python3 is missing, so no receipt can be written" >&2; exit 2; }
dir="${TMPDIR:-/tmp}/$CLAUDE_CODE_SESSION_ID/over-to-you-receipts"
mkdir -p "$dir" || exit 2
log=$(mktemp "$dir/.$id.XXXXXX") || exit 2 # mutant-ok: mkdir -p made the folder a line above, so mktemp fails here only on a full disk
trap 'rm -f "$log"' EXIT
at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
max=${RAN_MAX_BYTES:-52428800}
# The reader lets go of ran.sh's own output, so a lingering child never holds
# open the pipe of a caller that captures ran.sh.
# dd writes each block as it comes; head holds its output until end of input,
# which a lingering child delays.
exec 3> >(exec > /dev/null 2>&1; dd of="$log" bs=64K count="$max" iflag=count_bytes status=none; cat)
reader=$!
timeout -k "${RAN_GRACE:-5}" "${RAN_TIMEOUT:-600}" "$@" >&3 2>&1 3>&-
status=$?
# RAN_HOLD seconds on, a passing check runs again: a server can answer a
# check seconds after boot and crash a minute later. The receipt's hold is 0
# unless both runs passed.
hold=0
if [ "$status" = 0 ] && [ "${RAN_HOLD:-0}" -gt 0 ]; then
  sleep "$RAN_HOLD"
  timeout -k "${RAN_GRACE:-5}" "${RAN_TIMEOUT:-600}" "$@" >&3 2>&1 3>&-
  status=$?
  [ "$status" = 0 ] && hold=$RAN_HOLD
fi
exec 3>&-
# The reader ends at end of input, unless a child still holds the pipe; the
# wait is bounded so that child never holds ran.sh open.
timeout 1 tail -s 0.05 --pid="$reader" -f /dev/null # mutant-ok: head flushes in well under the bound, so only a stalled disk would show the wait missing
cat "$log"
head=$(git rev-parse HEAD 2>/dev/null || true)
# python3, which checklist.py needs anyway, writes the receipt.
python3 -I -c 'import json, sys
keys = ("id", "command", "exit", "at", "head", "cwd", "hold", "tail")
got = dict(zip(keys, sys.argv[1:]))
got["exit"] = int(got["exit"])
got["hold"] = int(got["hold"])
print(json.dumps(got))' "$id" "$*" "$status" "$at" "$head" "$PWD" "$hold" "$(tail -n 20 "$log")" > "$dir/$id.json"
echo "ran.sh: receipt $dir/$id.json, exit $status" >&2
exit "$status"
