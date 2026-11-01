#!/usr/bin/env bash
# Stop hook (guard_no_v1, off by default): an effort ships complete. When the
# agent's last reply offers found work as a follow-up pull request, a later
# ticket or a v2, keeps an open ticket out of the pull request, or asks
# whether to fold it in, leave it for later or take a ticket next, the
# stop is blocked once with a steer: fold it in, then report what was folded.
# A sentence that names a wait (Waits on, waits on) or quotes the user (as you
# said) goes through. It steers once per turn: with stop_hook_active set, the
# reply goes through, so a misjudged one never loops.
set -u
case "${CLAUDE_PLUGIN_OPTION_GUARD_NO_V1:-}" in true|1) ;; *) exit 0 ;; esac
payload=$(cat)
[ "$(jq -r '.stop_hook_active // false' <<<"$payload" 2>/dev/null)" = false ] || exit 0
transcript=$(jq -r '.transcript_path // ""' <<<"$payload" 2>/dev/null)
[ -f "$transcript" ] || exit 0 # mutant-ok delete: tail reads nothing from a missing file, so no offer is found and the hook exits 0
# The agent's text since the user's last typed message: its chat text and the
# messages it sent with SendUserMessage.
said=$(tail -n 400 "$transcript" | jq -rs '
  (map(.type == "user" and ((.message.content | type) == "string" or any(.message.content[]?; .type == "text"))) | rindex(true)) as $u
  | .[(($u // -1) + 1):][] | select(.type == "assistant") | .message.content[]?
  | if .type == "text" then .text elif .type == "tool_use" and .name == "SendUserMessage" then .input.message else empty end' 2>/dev/null)
offers=$(printf '%s\n' "$said" | tr '\n' ' ' | sed 's/\([.?!]\) /\1\n/g' \
  | grep -iE '(follow-?up|separate|another|later|future) (pr|pull request|ticket|issue|effort|star)|(ticket|pr|pull request|issue)[^.?!]* (for )?later|\bv2\b|fold (it|that|them|this) in,? or |(left|kept) (it|them|that|this) out of (this|the) (pr|pull request)|(in|into|gets?|needs?) (its|their) own (pr|pull request)|(still want|should i (take|do|fix|build)|want me to (take|do|fix|build))[^.?!]*(#[0-9]+|(issue|ticket) #?[0-9]+)' \
  | grep -viE 'waits on|as you (said|asked)')
[ -n "$offers" ] || exit 0
jq -n --arg o "$offers" '{decision:"block", reason:("Never a V1: this effort ships complete. Fold this found work, and every open ticket here that waits on no one, into the current pull request now, then report what you folded in. Close open tickets before you open new ones: the summit is closing more than you open. Park only work that waits on the user'"'"'s decision, another person, a deploy or a repo out of reach, with a Waits on: line. A new behaviour no approved example names is noted for the user in one line, not filed as a ticket. The sentences:\n" + $o)}'
