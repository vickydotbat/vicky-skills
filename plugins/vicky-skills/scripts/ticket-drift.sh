#!/usr/bin/env bash
# SessionStart hook (startup only): part of the gamma shift. With gamma_shift at
# engage and drift_every_days at a number of days N (7 by default), it adds a
# ticket-drift check to gamma-shift's queue at the first session start in a
# repo after N days. The last check's time is
# kept in the repo's git folder, so a clone starts its own count. A repo whose
# docs/agents/issue-tracker.md has the line "Ticket drift: off" never gets
# one. The stamp is written before the agent starts, so a session that ends
# first skips the check until the next one is due. Off at 0, and off whenever
# gamma_shift is not engage.
set -u
[ "${CLAUDE_PLUGIN_OPTION_GAMMA_SHIFT:-off}" = engage ] || exit 0
days="${CLAUDE_PLUGIN_OPTION_DRIFT_EVERY_DAYS:-7}"
case "$days" in ''|*[!0-9]*) exit 0 ;; esac
[ "$days" -gt 0 ] || exit 0
cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0
gitdir=$(git rev-parse --git-common-dir 2>/dev/null) || exit 0
[ -n "$(git remote)" ] || exit 0 # a repo with no remote has no tracker or pull requests
[ -f docs/agents/issue-tracker.md ] || exit 0 # no tracker, no tickets to drift
grep -qix 'Ticket drift: off' docs/agents/issue-tracker.md 2>/dev/null && exit 0
stamp="$gitdir/ticket-drift-last"
now=$(date +%s)
last=$(cat "$stamp" 2>/dev/null)
case "$last" in ''|*[!0-9]*) last=0 ;; esac
[ $((now - last)) -ge $((days * 86400)) ] || exit 0
echo "$now" > "$stamp"
echo "drift_every_days is $days: a ticket-drift check is due. Add it to gamma-shift's engage queue, where it runs beside the builds, so the user's first request is served alongside it."
exit 0 # mutant-ok delete: the line above leaves status 0, so the script ends the same way
