#!/usr/bin/env bash
# PostToolUse hook (Bash; guard_repeat_call, on by default): the third call in
# a row with the same command and the same output gets one line telling the
# agent to change approach or ask. Output that changes between calls, such as a
# status poll that moves, resets the run. Hooks fire for each call inside a REPL
# script too, so a script's calls count the same way.
set -u
case "${CLAUDE_PLUGIN_OPTION_GUARD_REPEAT_CALL:-true}" in false | 0) exit 0 ;; esac
command -v jq >/dev/null || exit 0 # mutant-ok delete: without jq the read below fails and the hook exits 0 there
payload=$(cat)
sig=$(jq -r '[.tool_input.command // "", .tool_response.stdout // "", .tool_response.stderr // ""] | tojson' <<<"$payload" 2>/dev/null | cksum)
session=$(jq -r '.session_id // "none"' <<<"$payload" 2>/dev/null | tr -c 'A-Za-z0-9_-' _)
state="${REPEAT_CALL_STATE:-${TMPDIR:-/tmp}/vicky-skills-repeat-call}"
mkdir -p "$state" || exit 0
file="$state/$session"
read -r last count <"$file" 2>/dev/null || { last=""; count=0; }
if [ "$last" = "${sig// /_}" ]; then count=$((count + 1)); else count=1; fi
echo "${sig// /_} $count" >"$file"
[ "$count" = 3 ] || exit 0
# A status poll that still shows a run in flight is waiting, not looping.
jq -r '.tool_response.stdout // ""' <<<"$payload" | grep -Eqi '(pending|queued|in[_ -]progress|running|waiting)' && exit 0
jq -nc '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:"repeat-call-hint: you repeated the same call 3 times in a row with the same output. Change approach or ask the user."}}'
