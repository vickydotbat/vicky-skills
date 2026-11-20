#!/usr/bin/env bash
# Stop and PreToolUse (SendUserMessage) hook: every test the user is asked to
# run goes on an over-to-you page, never in chat. Agents had handed tests over
# as chat steps ("Test it like this: 1. Connect to the local server..."), which
# skips the skill's own runs, kits and receipts. When the reply, or the message
# about to be sent, hands the user a test and no over-to-you checklist is open
# or was opened this turn (open-draft.sh opens only one whose every item holds
# a ran: line), the reply is
# sent back to run over-to-you, and the message is refused before it is sent.
# A turn opens a checklist when open-draft.sh (or open-page.sh, which runs it)
# leaves its over-to-you-opened marker: a refused open leaves none.
# A Stop is sent back again while the reply still hands a test over, at most
# three times a turn, so a misread reply never loops for ever.
# shortcut: the hand-off is read from the words, so a phrasing the patterns
# miss slips past; outside brief mode the user has already read the reply
# when the stop is sent back.
# On unless the plugin option guard_user_test is false or 0.
set -u
case "${CLAUDE_PLUGIN_OPTION_GUARD_USER_TEST:-}" in false | 0) exit 0 ;; esac
command -v jq >/dev/null || exit 0 # mutant-ok delete: without jq every read below comes back empty and the hook exits 0
raw=$(cat)
event=$(jq -r '.hook_event_name // ""' <<<"$raw" 2>/dev/null)
if [ "$event" = PreToolUse ]; then
  [ "$(jq -r '.tool_name // ""' <<<"$raw" 2>/dev/null)" = SendUserMessage ] || exit 0
  words=$(jq -r '.tool_input.message // ""' <<<"$raw" 2>/dev/null | sed 's/`[^`]*`//g')
  transcript=$(jq -r '.transcript_path // ""' <<<"$raw" 2>/dev/null)
else
  export STOP_REPLY_REPEAT=1
  # shellcheck source=stop-reply.sh
  . "$(dirname "$0")/stop-reply.sh" <<<"$raw"
  words=$(prose)
fi
# The agent's own plans ("I'd test it with...", "then I'll check") are no hand-off.
mine=$(sed -E "s/\b(I|I'd|I'll|I will|I would|I can|I'm going to|we|we'll|we can|let me)( [a-z]+){0,2} (test|try|check|verify)\b//gI" <<<"$words")
handoff=$(grep -oiE "\b(test|try) (it|this|that|them)( out)? (like this|yourself|in[- ]game|in the (game|client|browser|app))\b|\bto (test|try|check|verify) (it|this|that|them)( out)? yourself\b|\b(you can|you could|you may|can you|could you|please|feel free to)( now| already| also)? (test|try)\b|\b(can you|could you|please)( now| also)? (re-?)?(check|verify)\b|\bwhen you (test|try|check|verify)\b|\b(steps to (test|verify)|how to test( it)?:|to test it:|to verify it:)|\b(test|try) (it|them|this) (on|from) (the |your |this |that )?(branch|main|checkout|local|server|client|build)\b|\blet me know (if|whether|how) (it|that|this|they) (works?|looks?|goes|feels?|behaves?)\b|\byou can test now\b|\btest (it|this|that|them) by\b|\b(give it|take it for) a (go|spin|try|whirl)\b|\bhow to try it\b|\b(please|can you|could you|feel free to)( now| also| just)? (play|run|load|launch|join|open|reload|restart|start)\b|\byou report back\b|\breport back (to me|what you)\b|\bconfirm (it|that|this|they|the [a-z]+) (works?|opens?|shows?|loads?|looks?)\b|^steps: *1\.|\bonce you('ve| have) (pulled|played|tried|tested|loaded|built|updated)\b" <<<"$mine" | head -1)
[ -n "$handoff" ] || exit 0
# The last typed message's time keys the cap and dates the turn.
sid=$(jq -r '.session_id // "none"' <<<"$raw" 2>/dev/null)
. "$(dirname "$0")/since-user.sh"
since=$(last_user_time "$transcript" || echo 0)
key=$since
# open-draft.sh leaves this marker only when it opened a checklist that passed
# its lint. It counts while that page is still open, or when it opened this turn.
marker="${TMPDIR:-/tmp}/$sid/over-to-you-opened"
if [ -f "$marker" ] && read -r pid at <"$marker"; then
  kill -0 "$pid" 2>/dev/null && exit 0
  [ "${at:-0}" -ge "$since" ] 2>/dev/null && exit 0
fi
steer="Your reply hands the user a test in chat (\"$handoff\"). Every test the user runs goes on an over-to-you page, never in chat. Start the over-to-you skill: run each check yourself first with its ran.sh, by any means the repo has (its test harness, a headless client, a browser script), and open the checklist it writes. When nothing is left for a person, report what you ran instead."
if [ "$event" = PreToolUse ]; then
  echo "user-test-guard: $steer Nothing was sent." >&2
  exit 2
fi
# The cap: three send-backs per user message, counted in the plugin's data folder.
state="${CLAUDE_PLUGIN_DATA:-${TMPDIR:-/tmp}}/user-test-guard"
mkdir -p "$state" 2>/dev/null
count=0
[ -f "$state/$sid" ] && IFS='|' read -r was n <"$state/$sid" && [ "$was" = "$key" ] && count=$n
[ "$count" -lt 3 ] || exit 0
echo "$key|$((count + 1))" >"$state/$sid"
jq -nc --arg r "$steer" '{decision:"block", reason:$r}'
