#!/usr/bin/env bash
# PreToolUse hook (Bash): refuses a wait that skips watch.sh: a foreground
# loop that sleeps and checks, a `sleep` over 30 seconds, or a sleeping loop
# of more than 60 rounds. Off unless the plugin option guard_poll_pace is true.
case "${CLAUDE_PLUGIN_OPTION_GUARD_POLL_PACE:-}" in true|1) ;; *) exit 0 ;; esac
command -v jq >/dev/null || exit 0 # mutant-ok delete: without the tool every later read comes back empty, and the hook exits 0 the same way
payload=$(cat)
cmd=$(jq -r '.tool_input.command // ""' <<<"$payload")
# A heredoc body is text, unless the heredoc feeds a shell or an interpreter.
cmd=$(awk -v code=1 -f "$(dirname "$0")/heredoc-strip.awk" <<<"$cmd")
grep -Eq '(^|[^[:alnum:]_])sleep[[:space:]]' <<<"$cmd" || exit 0
refuse() { echo "poll-pace: $1. Wait with \${CLAUDE_PLUGIN_ROOT}/scripts/watch.sh '<check>', run by the Monitor tool or as a background command: it checks every 30 seconds, at most 60 times." >&2; exit 2; }
[ "$(jq -r '.tool_input.run_in_background // false' <<<"$payload")" = true ] || {
  grep -Eq '(^|[^[:alnum:]_])(while|until|for)[[:space:]]' <<<"$cmd" && refuse "a foreground loop that sleeps and checks holds the session"
}
while read -r n; do
  [ "${n%.*}" -gt 30 ] && refuse "sleep $n waits more than 30 seconds"
done < <(grep -Eo '(^|[^[:alnum:]_])sleep[[:space:]]+[0-9]+(\.[0-9]+)?' <<<"$cmd" | grep -Eo '[0-9]+(\.[0-9]+)?$')
while read -r n; do
  [ "$n" -gt 60 ] && refuse "a loop of $n rounds polls more than 60 times"
done < <(grep -Eo 'seq[[:space:]]+(1[[:space:]]+)?[0-9]+|\{1\.\.[0-9]+\}' <<<"$cmd" | grep -Eo '[0-9]+\}?$' | tr -d '}')
exit 0 # mutant-ok delete: the loop above ends with status 0 on every path
