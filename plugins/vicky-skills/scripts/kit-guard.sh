#!/usr/bin/env bash
# Stop hook (guard_kit_cleanup, on by default): once an over-to-you sitting has
# closed, the turn ends only when the kits recorded for it are gone, so kit
# cleanup never waits on a merge or a question. open-draft.sh leaves
# over-to-you-opened in the session folder: the page's pid, the time it opened
# and the checklist. The sitting has closed once that pid is gone. Each path
# kit.sh recorded at or before that time and still in place blocks the stop,
# naming kit.sh clean, at most 3 times in a row.
set -u
case "${CLAUDE_PLUGIN_OPTION_GUARD_KIT_CLEANUP:-true}" in false | 0) exit 0 ;; esac
command -v jq >/dev/null || exit 0 # mutant-ok delete: without jq the session id reads empty and the hook exits 0 on the next line
session=$(jq -r '.session_id // ""' 2>/dev/null)
case $session in "" | */* | . | ..) exit 0 ;; esac
dir="${TMPDIR:-/tmp}/$session"
opened="$dir/over-to-you-opened"; rec="$dir/over-to-you-kits"; count="$dir/kit-guard.count"
[ -f "$opened" ] && [ -f "$rec" ] || exit 0 # mutant-ok: a missing file reads as no page and no kits, and the stop goes through below
read -r pid at _ <"$opened" 2>/dev/null
# The page is still open: the sitting waits on the user.
kill -0 "$pid" 2>/dev/null && exit 0
left=$(while IFS=$'\t' read -r t p; do
  if [[ $t =~ ^[0-9]+$ ]] && [ "$t" -le "$at" ] && { [ -e "$p" ] || [ -L "$p" ]; }; then printf '%s\n' "$p"; fi
done <"$rec")
if [ -z "$left" ]; then rm -f "$count"; exit 0; fi
n=$(cat "$count" 2>/dev/null)
[[ $n =~ ^[0-9]+$ ]] || n=0 # mutant-ok delete: a count that is no number fails the test below and counts as 0 in the sum
if [ "$n" -ge 3 ]; then
  rm -f "$count"
  jq -nc --arg l "$left" '{systemMessage:("kit-guard: the sitting closed, and its kits are still in place after 3 blocks:\n" + $l)}'
  exit 0
fi
echo $((n + 1)) >"$count"
kit="$(cd "$(dirname "$0")/.." && pwd)/skills/building/over-to-you/scripts/kit.sh"
jq -nc --arg l "$left" --arg k "$kit" '{decision:"block",reason:("kit-guard: the over-to-you sitting has closed, and its kits are still in place:\n" + $l + "\nRemove them now, unasked: bash " + $k + " clean. Never park kit cleanup behind a merge, and never ask the user to approve it.")}'
