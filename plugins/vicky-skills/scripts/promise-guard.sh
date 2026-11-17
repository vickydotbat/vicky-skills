#!/usr/bin/env bash
# Stop hook: an agent that owns up to a mistake tends to end on a promise
# ("from now on I'll read a script before I run it"), which the next session
# never reads. engrave says a serious snag becomes a law in the turn it is
# caught. When the agent's reply since the user's last message promises to do
# better, and the turn neither started engrave nor printed its
# "📓 Engraved:" line, this sends the reply back through engrave. On unless
# the plugin option guard_promise is false or 0.
set -u
case "${CLAUDE_PLUGIN_OPTION_GUARD_PROMISE:-}" in false | 0) exit 0 ;; esac
command -v jq >/dev/null || exit 0 # mutant-ok delete: stop-reply.sh reads with jq, and without it the reply reads empty and the hook exits 0
. "$(dirname "$0")/stop-reply.sh"
words=$(prose)
promise=$(grep -oiE "(from now on|going forward|in future|next time),? I('ll| will)[^.]*|I('ll| will) remember[^.]*|I (won't|will not|will never|'ll never) [^.]* again|lesson learned" <<<"$words" | head -1)
[ -n "$promise" ] || exit 0
grep -qF '📓 Engraved:' <<<"$said" && exit 0
jq -e '.[] | select(.type == "tool_use" and .name == "Skill" and ((.input.skill // "") | test("(^|:)engrave$")))' <<<"$turn" >/dev/null 2>&1 && exit 0
jq -nc --arg p "$promise" '{decision:"block", reason:("Your reply promises to do better (\"" + $p + "\"). The next session never reads a promise. Run the engrave skill on the snag now: build its law this turn, and end the reply with its \"📓 Engraved:\" line. When the reply only quotes someone else, say so in one line and stop.")}'
