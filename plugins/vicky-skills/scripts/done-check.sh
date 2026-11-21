#!/usr/bin/env bash
# Stop and SubagentStop hook (guard_done_check, on by default): a turn or a
# subagent that changed the working tree ends only when the repo's own check
# passes. The check is the "Check: <command>" line of docs/agents/testing.md;
# "Check: none" turns it off for the repo. UserPromptSubmit and SubagentStart
# record the tree's fingerprint, so a change made any way (an edit, a REPL
# script, a shell redirect) counts. A failing check blocks the stop with its
# last 40 lines, at most 3 times in a row, then lets it through saying the
# check still fails. A check past DONE_CHECK_TIMEOUT seconds (300) blocks once
# saying it timed out, and the next stop goes through without running it.
set -u
case "${CLAUDE_PLUGIN_OPTION_GUARD_DONE_CHECK:-true}" in false | 0) exit 0 ;; esac
command -v jq >/dev/null || exit 0 # mutant-ok delete: without jq every read below is empty and the hook exits 0 at the repo check
payload=$(cat)
field() { jq -r ".$1 // \"\"" <<<"$payload" 2>/dev/null; }
event=$(field hook_event_name); cwd=$(field cwd); session=$(field session_id); agent=$(field agent_id)
root=$(git -C "${cwd:-.}" rev-parse --show-toplevel 2>/dev/null) || exit 0
state="${DONE_CHECK_STATE:-${TMPDIR:-/tmp}/vicky-skills-done-check}"
mkdir -p "$state" || exit 0
key=$(tr -c 'A-Za-z0-9_-' _ <<<"${session:-none}.${agent:-main}")
sess=$(tr -c 'A-Za-z0-9_-' _ <<<"${session:-none}")
fingerprint() { { git -C "$root" status --porcelain=v1 --untracked-files=all; git -C "$root" diff HEAD; } 2>/dev/null | cksum; }
case "$event" in
  UserPromptSubmit | SubagentStart)
    fingerprint >"$state/$key.base"; rm -f "$state/$key.count" "$state/$key.timedout"; exit 0 ;;
  Stop | SubagentStop) ;;
  *) exit 0 ;;
esac
[ -f "$state/$key.base" ] && [ "$(fingerprint)" != "$(cat "$state/$key.base")" ] || exit 0
line=$(grep -m1 -E '^Check:' "$root/docs/agents/testing.md" 2>/dev/null)
cmd=$(sed -E 's/^Check:[[:space:]]*//; s/[[:space:]]+$//' <<<"$line")
if [ -z "$cmd" ]; then
  [ -f "$state/$sess.noted" ] && exit 0
  touch "$state/$sess.noted"
  jq -nc '{systemMessage:"done-check: docs/agents/testing.md has no \"Check: <command>\" line, so no check ran before this turn ended. Add one, or \"Check: none\"."}'
  exit 0 # mutant-ok delete: the empty command after it runs and passes, which also exits 0 with nothing added
fi
[ "$cmd" = none ] && exit 0
if [ -f "$state/$key.timedout" ]; then
  rm -f "$state/$key.timedout"; fingerprint >"$state/$key.base"; exit 0
fi
count=$(cat "$state/$key.count" 2>/dev/null || echo 0)
if [ "$count" -ge 3 ]; then
  rm -f "$state/$key.count"; fingerprint >"$state/$key.base"
  jq -nc --arg c "$cmd" '{systemMessage:("done-check: the check still fails after 3 blocks in a row: " + $c)}'
  exit 0
fi
limit=${DONE_CHECK_TIMEOUT:-300}
out=$(cd "$root" && timeout "$limit" bash -c "$cmd" 2>&1); rc=$?
if [ $rc = 0 ]; then
  rm -f "$state/$key.count"; fingerprint >"$state/$key.base"; exit 0
fi
echo $((count + 1)) >"$state/$key.count"
if [ $rc = 124 ]; then
  touch "$state/$key.timedout"
  jq -nc --arg c "$cmd" --arg l "$limit" '{decision:"block",reason:("done-check: the check timed out after " + $l + " seconds: " + $c + ". Make it faster, or end the turn again to stop without it.")}'
  exit 0
fi
jq -nc --arg c "$cmd" --arg o "$(tail -n 40 <<<"$out")" '{decision:"block",reason:("done-check: the repo check failed (" + $c + "). Fix it before you end the turn. Its last 40 lines:\n" + $o)}'
