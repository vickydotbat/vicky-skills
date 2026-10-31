#!/usr/bin/env bash
# PreToolUse hook (Bash): refuses a wait longer than the poll pace allows: a
# `sleep` over 30 seconds, or a sleeping loop of more than 60 rounds. Off
# unless the plugin option guard_poll_pace is true.
case "${CLAUDE_PLUGIN_OPTION_GUARD_POLL_PACE:-}" in true|1) ;; *) exit 0 ;; esac
command -v jq >/dev/null || exit 0
cmd=$(jq -r '.tool_input.command // ""')
grep -Eq '(^|[^[:alnum:]_])sleep[[:space:]]' <<<"$cmd" || exit 0
refuse() { echo "poll-pace: $1. Poll at most every 30 seconds, at most 60 times (30 minutes), then report what the gate waits on." >&2; exit 2; }
while read -r n; do
  [ "${n%.*}" -gt 30 ] && refuse "sleep $n waits more than 30 seconds"
done < <(grep -Eo '(^|[^[:alnum:]_])sleep[[:space:]]+[0-9]+(\.[0-9]+)?' <<<"$cmd" | grep -Eo '[0-9]+(\.[0-9]+)?$')
while read -r n; do
  [ "$n" -gt 60 ] && refuse "a loop of $n rounds polls more than 60 times"
done < <(grep -Eo 'seq[[:space:]]+(1[[:space:]]+)?[0-9]+|\{1\.\.[0-9]+\}' <<<"$cmd" | grep -Eo '[0-9]+\}?$' | tr -d '}')
exit 0
