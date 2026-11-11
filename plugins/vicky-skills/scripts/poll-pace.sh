#!/usr/bin/env bash
# PreToolUse hook (Bash): refuses a wait that skips watch.sh: a foreground
# loop that sleeps and checks or a `sleep` over 30 seconds, in the foreground
# only: Monitor and background
# runs go through. Off unless the plugin option guard_poll_pace is true.
case "${CLAUDE_PLUGIN_OPTION_GUARD_POLL_PACE:-}" in true|1) ;; *) exit 0 ;; esac
command -v jq >/dev/null || exit 0 # mutant-ok delete: without the tool every later read comes back empty, and the hook exits 0 the same way
payload=$(cat)
cmd=$(jq -r '.tool_input.command // ""' <<<"$payload")
# A subagent's output file is its transcript, and the subagent reports back on
# its own when it ends, so a wait on that file, in any form, waits on nothing.
grep -Eq 'tasks/a[0-9a-f]{16}\.output' <<<"$cmd" && { echo "poll-pace: this waits on a subagent's output file. A subagent reports back on its own: its hand-back message and a task notification arrive when it ends, and its file never holds the text a check would grep for. Nothing in this command ran: work on what doesn't wait on it, or end the turn with a line saying which agent is still running." >&2; exit 2; }
# A heredoc body is text, unless the heredoc feeds a shell.
cmd=$(awk -v code=1 -f "$(dirname "$0")/heredoc-strip.awk" <<<"$cmd")
# A quoted string is text, unless a shell runs it (bash -c, eval, watch.sh):
# those are unquoted first, so they stay as code.
run='((bash|sh|zsh)[[:space:]]+-[a-z]*c|eval|watch\.sh)[[:space:]]+'
# A runner that itself sits inside quoted text is text too: unquote only when
# one shows once the quotes are masked.
masked=$(awk -f "$(dirname "$0")/quote-mask.awk" <<<"$cmd") || masked=$cmd
grep -Eq "$run" <<<"$masked" && cmd=$(sed -E "s/${run}'([^']*)'/\\1 \\3/g; s/${run}\"(([^\"\\]|\\.)*)\"/\\1 \\3/g" <<<"$cmd")
# The rest of the quoted text is masked by the shell's own quote rules, so a
# quote spliced into a string ('it'"'"'s') never leaves its words loose.
masked=$(awk -f "$(dirname "$0")/quote-mask.awk" <<<"$cmd") && cmd=$masked
grep -Eq '(^|[^[:alnum:]_])sleep[[:space:]]' <<<"$cmd" || exit 0 # mutant-ok delete: a fast path: with no sleep, no check below refuses
refuse() { echo "poll-pace: $1. Wait with \${CLAUDE_PLUGIN_ROOT}/scripts/watch.sh '<check>', run by the Monitor tool or as a background command: it checks every 30 seconds, at most 60 times. Nothing in this command ran, not even its other steps: rerun the ones that need no change on their own." >&2; exit 2; }
# The Monitor tool runs its command in the background, like run_in_background.
# Its hooks can arrive under the Bash matcher with tool_name Bash, so its own
# timeout_ms field marks it too.
# A wait in the background holds nothing, and Monitor caps it with its own timeout, so it goes through.
[ "$(jq -r '.tool_name == "Monitor" or .tool_input.run_in_background == true or (.tool_input | has("timeout_ms"))' <<<"$payload")" = true ] && exit 0
grep -Eq '(^|[^[:alnum:]_])(while|until|for)[[:space:]]' <<<"$cmd" && refuse "a foreground loop that sleeps and checks holds the session"
while read -r n; do
  [ "${n%.*}" -gt 30 ] && refuse "sleep $n waits more than 30 seconds"
done < <(grep -Eo '(^|[^[:alnum:]_])sleep[[:space:]]+[0-9]+(\.[0-9]+)?' <<<"$cmd" | grep -Eo '[0-9]+(\.[0-9]+)?$')
exit 0 # mutant-ok delete: the loop above ends with status 0 on every path
