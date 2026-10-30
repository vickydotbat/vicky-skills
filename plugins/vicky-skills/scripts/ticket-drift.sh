#!/usr/bin/env bash
# SessionStart hook (startup only): with the plugin option drift_every_days at
# a number of days N, it asks the agent for a background ticket-drift check at
# the first session start in a repo after N days. The last check's time is
# kept in the repo's git folder, so a clone starts its own count. A repo whose
# docs/agents/issue-tracker.md has the line "Ticket drift: off" never gets
# one. Off at 0, the default.
set -u
days="${CLAUDE_PLUGIN_OPTION_DRIFT_EVERY_DAYS:-0}"
case "$days" in ''|*[!0-9]*) exit 0 ;; esac
[ "$days" -gt 0 ] || exit 0
cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0
gitdir=$(git rev-parse --git-common-dir 2>/dev/null) || exit 0
grep -qix 'Ticket drift: off' docs/agents/issue-tracker.md 2>/dev/null && exit 0
stamp="$gitdir/ticket-drift-last"
now=$(date +%s)
last=$(cat "$stamp" 2>/dev/null)
case "$last" in ''|*[!0-9]*) last=0 ;; esac
[ $((now - last)) -ge $((days * 86400)) ] || exit 0
echo "$now" > "$stamp"
echo "drift_every_days is $days: a ticket-drift check is due. Start the ticket-drift agent now as one background subagent, so the user's first request is served alongside it."
exit 0
