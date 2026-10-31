#!/usr/bin/env bash
# PreToolUse hook (Bash): refuses a command that runs `tea` without closing
# stdin. tea blocks on an open stdin, and a retry can post twice. Off unless
# the plugin option guard_tea_stdin is true. Needs jq and gawk; without them it says
# so and stays off.
set -u
case "${CLAUDE_PLUGIN_OPTION_GUARD_TEA_STDIN:-}" in true | 1) ;; *) exit 0 ;; esac
command -v jq >/dev/null || { echo "tea-stdin: jq is missing, guard is off" >&2; exit 0; } # mutant-ok delete: without the tool every later read comes back empty, and the hook exits 0 the same way
command -v gawk >/dev/null || { echo "tea-stdin: gawk is missing, guard is off" >&2; exit 0; } # mutant-ok delete: without the tool every later read comes back empty, and the hook exits 0 the same way
command="$(jq -r '.tool_input.command // ""' 2>/dev/null)"
grep -Eq '(^|[^[:alnum:]_-])tea([[:space:]]|$)' <<<"$command" || exit 0 # mutant-ok delete: a fast path: the checks below find nothing to refuse in such a command
fixed="$(printf '%s' "$command" | gawk -f "$(dirname "$0")/tea-stdin.awk" || true)"
[ -n "$fixed" ] || exit 0
echo "tea-stdin: tea blocks on an open stdin and a retry can post twice; add </dev/null to each tea call and run again:" >&2
printf '%s\n' "$fixed" >&2
exit 2
