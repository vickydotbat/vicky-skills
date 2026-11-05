#!/usr/bin/env bash
# Lists the sessions the familiar watches: one line per live session,
# "<session id> <transcript> <working folder>". A session is live while its
# transcript changed in the last day and does not end on the cost-state line
# Claude Code writes when a session exits, and, where Claude Code keeps its
# per-session process records, while that process runs. The familiar's own session
# ($CLAUDE_CODE_SESSION_ID) is left out. A session working in a repo whose
# docs/agents/issue-tracker.md says "Familiar: off" prints as "OFF <line>".
# With --new it lists again every minute (FAMILIAR_SESSIONS_EVERY seconds)
# and prints "NEW <line>" once for each session not named after --new, the
# ids the caller already watches, so one that started between the caller's
# list and this check still shows. With no ids, the sessions live at its
# start are known. It runs 30 rounds (FAMILIAR_SESSIONS_ROUNDS), so a Monitor
# re-arms it.
# The mutation tool covers plugins/vicky-skills/scripts only: mutate this script by hand, with sentinels.
set -u
dir=${FAMILIAR_PROJECTS_DIR:-$HOME/.claude/projects}
# Claude Code keeps one record per running session, "<pid>.json" naming its
# sessionId. Where any exist, a session counts only while its process runs.
records=${FAMILIAR_SESSIONS_DIR:-$(dirname "$dir")/sessions}
running() {
  local f pid
  for f in "$records"/*.json; do
    [ -e "$f" ] || continue
    pid=$(jq -r '.pid // empty' "$f" 2>/dev/null)
    [ -n "$pid" ] && [ -d "/proc/$pid" ] && jq -r '.sessionId // empty' "$f" 2>/dev/null
  done
}
list() {
  local alive; alive=$(running)
  find "$dir" -mindepth 2 -maxdepth 2 -name '*.jsonl' -mmin -1440 2>/dev/null | sort | while IFS= read -r f; do
    id=$(basename "$f" .jsonl)
    [ "$id" = "${CLAUDE_CODE_SESSION_ID:-}" ] && continue
    [ "$(tail -n 1 "$f" | jq -r '.type // empty' 2>/dev/null)" = cost-state ] && continue
    compgen -G "$records/*.json" >/dev/null && ! grep -qxF "$id" <<<"$alive" && continue
    cwd=$(grep -m1 '"cwd"' "$f" | jq -r '.cwd // empty' 2>/dev/null)
    top=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$cwd")
    if grep -qiE '^Familiar:[[:space:]]*off[[:space:]]*$' "$top/docs/agents/issue-tracker.md" 2>/dev/null; then printf 'OFF '; fi
    printf '%s %s %s\n' "$id" "$f" "$cwd"
  done
}
[ "${1:-}" = --new ] || { list; exit 0; }
shift
if [ $# -gt 0 ]; then seen=$(printf '%s\n' "$@"); else seen=$(list | sed 's/^OFF //' | cut -d' ' -f1); fi
for _ in $(seq 1 "${FAMILIAR_SESSIONS_ROUNDS:-30}"); do
  sleep "${FAMILIAR_SESSIONS_EVERY:-60}"
  while IFS= read -r line; do
    rest=${line#OFF }; id=${rest%% *}
    grep -qxF "$id" <<<"$seen" && continue
    seen+=$'\n'"$id"
    printf 'NEW %s\n' "$line"
  done < <(list)
done
