#!/usr/bin/env bash
# keep-awake: holds one systemd-inhibit sleep lock while any Claude Code
# agent on the machine works. A mark is a file per working agent: a session's
# turn, or each subagent it starts. The turn's or subagent's end clears its
# mark, and the session's close clears them all. A mark idle past
# KEEP_AWAKE_IDLE minutes drops out, since an Esc interrupt fires no hook.
# One holder process keeps the lock while any mark is left, then exits.
# Off unless the keep_awake option is on.
case "${CLAUDE_PLUGIN_OPTION_KEEP_AWAKE:-}" in true|1) ;; *) exit 0 ;; esac
command -v systemd-inhibit >/dev/null 2>&1 || exit 0
command -v flock >/dev/null 2>&1 || exit 0

input=$(cat)
event=$(jq -r '.hook_event_name // empty' <<<"$input" 2>/dev/null)
session=$(jq -r '.session_id // empty' <<<"$input" 2>/dev/null)
agent=$(jq -r '.agent_id // empty' <<<"$input" 2>/dev/null)
case "$session" in ''|*/*|.*) exit 0 ;; esac
case "$agent" in */*|.*) exit 0 ;; esac
mark=$session${agent:+.$agent}
dir="${KEEP_AWAKE_DIR:-${XDG_RUNTIME_DIR:-/tmp}/vicky-skills-keep-awake-$(id -u)}"
poll="${KEEP_AWAKE_POLL:-5}"  # mutant-ok delete: without it sleep fails and the holder busy-loops, a CPU cost no output shows
# KEEP_AWAKE_IDLE: minutes a mark may sit untouched. Anything but a whole number means 30.
case "${KEEP_AWAKE_IDLE:-}" in ''|*[!0-9]*) idle=30 ;; *) idle=$KEEP_AWAKE_IDLE ;; esac

case "$event" in
  UserPromptSubmit|SubagentStart)
    # The mark holds the Claude Code process id, so a session that crashed or was killed drops out.
    owner="${KEEP_AWAKE_OWNER:-}" p=$PPID
    while [ -z "$owner" ] && [ "${p:-1}" -gt 1 ]; do
      case "$(cat "/proc/$p/comm" 2>/dev/null)" in *claude*) owner=$p ;; esac
      p=$(awk '{print $4}' "/proc/$p/stat" 2>/dev/null)
    done
    { mkdir -p "$dir" && echo "${owner:-$PPID}" > "$dir/$mark"; } 2>/dev/null || exit 0
    # shortcut: a prompt in the holder's last poll misses the lock until the next prompt.
    setsid flock -n "$dir.holder" systemd-inhibit --what=sleep:idle --who="Claude Code" \
      --why="A Claude Code session is working" --mode=block \
      sh -c 'while [ -n "$(ls -A "$1" 2>/dev/null)" ]; do for m in "$1"/*; do kill -0 "$(cat "$m" 2>/dev/null)" 2>/dev/null || rm -f "$m"; done; find "$1" -type f -mmin "+$3" -delete 2>/dev/null; sleep "$2"; done' keep-awake "$dir" "$poll" "$idle" \
      </dev/null >/dev/null 2>&1 &
    ;;
  PostToolUse) [ -f "$dir/$mark" ] && touch "$dir/$mark" ;;
  Stop|StopFailure|SubagentStop) rm -f "$dir/$mark" ;;
  SessionEnd) rm -f "$dir/$session" "$dir/$session".* ;;
esac
exit 0  # mutant-ok delete: every branch above already ends with status 0
