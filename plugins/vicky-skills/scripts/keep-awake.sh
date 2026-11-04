#!/usr/bin/env bash
# keep-awake: holds one systemd-inhibit sleep lock while any Claude Code
# session on the machine has a turn running. A prompt marks its session as
# working, and the turn's end or the session's close clears the mark. One
# holder process keeps the lock while any mark is left, then exits.
# Off unless the keep_awake option is on.
case "${CLAUDE_PLUGIN_OPTION_KEEP_AWAKE:-}" in true|1) ;; *) exit 0 ;; esac
command -v systemd-inhibit >/dev/null 2>&1 || exit 0
command -v flock >/dev/null 2>&1 || exit 0

input=$(cat)
event=$(jq -r '.hook_event_name // empty' <<<"$input" 2>/dev/null)
session=$(jq -r '.session_id // empty' <<<"$input" 2>/dev/null)
case "$session" in ''|*/*|.*) exit 0 ;; esac
dir="${KEEP_AWAKE_DIR:-${XDG_RUNTIME_DIR:-/tmp}/vicky-skills-keep-awake-$(id -u)}"
poll="${KEEP_AWAKE_POLL:-5}"  # mutant-ok delete: without it the holder spins on a failing sleep, which no test can time

case "$event" in
  UserPromptSubmit)
    { mkdir -p "$dir" && touch "$dir/$session"; } 2>/dev/null || exit 0
    # shortcut: a prompt landing in the holder's last poll can miss the lock until the next prompt, fine at a 5 s poll.
    setsid flock -n "$dir.holder" systemd-inhibit --what=sleep:idle --who="Claude Code" \
      --why="A Claude Code session is working" --mode=block \
      sh -c 'while [ -n "$(ls -A "$1" 2>/dev/null)" ]; do sleep "$2"; done' keep-awake "$dir" "$poll" \
      </dev/null >/dev/null 2>&1 &
    ;;
  Stop|SessionEnd) rm -f "$dir/$session" ;;
esac
exit 0  # mutant-ok delete: every branch above already ends with status 0
