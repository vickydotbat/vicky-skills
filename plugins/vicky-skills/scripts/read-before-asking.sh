#!/usr/bin/env bash
# Stop hook (guard_read_before_asking, on by default): a decision the user may
# already have made is looked up before it is asked. When the agent's last
# reply opens a "🚪 Waiting on you" gate that offers coded options (O1, O2)
# and the session never read a tracker item (read-item.sh, or the tracker's own
# read: gh or tea issue and pr views, a Plane get), the stop is blocked once
# with a steer to read the effort's ticket and chart first. Every other case,
# and the second stop of a turn, goes through.
set -u
case "${CLAUDE_PLUGIN_OPTION_GUARD_READ_BEFORE_ASKING:-}" in false|0) exit 0 ;; esac
# shellcheck source=stop-reply.sh
. "$(dirname "$0")/stop-reply.sh"
words=$(prose)
grep -qE '🚪 *Waiting on you' <<<"$words" || exit 0
grep -qE '\bO[0-9]+\b' <<<"$words" || exit 0
grep -E '"name":"Bash"' "$transcript" 2>/dev/null | jq -r '.message.content[]? | select(.type == "tool_use" and .name == "Bash") | .input.command // empty' 2>/dev/null \
  | grep -qE 'read-item\.sh|\bgh +(issue|pr) +view\b|\btea +(issues?|pulls?|pr) +[0-9]|\bplane +(get|show|view|read)\b' && exit 0
jq -n '{decision:"block", reason:"You are asking the user to pick between options, and this session never read a ticket. A council or an earlier answer may already have settled it. Read the effort ticket and its star chart whole with read-item.sh <id>. When a line there settles the choice, quote it and build on it instead of asking. Otherwise ask again, naming what you read."}'
