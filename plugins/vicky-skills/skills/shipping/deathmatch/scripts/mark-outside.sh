#!/usr/bin/env bash
# mark-outside.sh <session id> <what was read>: records that this session read
# outside text (an outside pull request, bug report or review), so
# outside-text-guard refuses its pushes, tickets and posts for the rest of it.
set -u
sid=${1:?usage: mark-outside.sh <session id> <what was read>}
dir="${CLAUDE_PLUGIN_DATA:?}/outside-read"
mkdir -p "$dir"
printf '%s\n' "${2:-outside text}" >>"$dir/$sid"
