#!/usr/bin/env bash
# Lists the sessions the familiar watches: one line per live session,
# "<session id> <transcript> <working folder>". A session is live while its
# transcript changed in the last day and does not end on the cost-state line
# Claude Code writes when a session exits. The familiar's own session
# ($CLAUDE_CODE_SESSION_ID) is left out.
# The mutation tool covers plugins/vicky-skills/scripts only: mutate this script by hand, with sentinels.
set -u
dir=${FAMILIAR_PROJECTS_DIR:-$HOME/.claude/projects}
find "$dir" -mindepth 2 -maxdepth 2 -name '*.jsonl' -mmin -1440 2>/dev/null | sort | while IFS= read -r f; do
  id=$(basename "$f" .jsonl)
  [ "$id" = "${CLAUDE_CODE_SESSION_ID:-}" ] && continue
  [ "$(tail -n 1 "$f" | jq -r '.type // empty' 2>/dev/null)" = cost-state ] && continue
  cwd=$(grep -m1 '"cwd"' "$f" | jq -r '.cwd // empty' 2>/dev/null)
  printf '%s %s %s\n' "$id" "$f" "$cwd"
done
