#!/usr/bin/env bash
# Stop hook (guard_no_v1, off by default): an effort ships complete. When the
# agent's last reply offers found work as a follow-up pull request, a later
# ticket or a v2, keeps an open ticket out of the pull request, or asks
# whether to fold it in, leave it for later or take a ticket next, the
# stop is blocked once with a steer: fold it in, then report what was folded.
# A v2 counts only after a word such as "a" or "for", so a check labelled
# V2 is no offer, and code in backticks is dropped first. Ticket words match
# only as whole words, so "pr" inside "surprises" is no offer, and text in
# double quotes is a mention, dropped like code. A sentence that
# names a wait (Waits on, waits on) or quotes the user (as you said) goes
# through. It steers once per turn: with stop_hook_active set, the
# reply goes through, so a misjudged one never loops.
set -u
case "${CLAUDE_PLUGIN_OPTION_GUARD_NO_V1:-}" in true|1) ;; *) exit 0 ;; esac
# shellcheck source=stop-reply.sh
. "$(dirname "$0")/stop-reply.sh"
offers=$(prose | sed 's/"[^"]*"//g; s/“[^”]*”//g' | tr '\n' ' ' | sed 's/\([.?!]\) /\1\n/g' \
  | grep -iE '\b(follow-?up|separate|another|later|future) (pr|pull request|ticket|issue|effort|star)|\b(ticket|pr|pull request|issue)\b[^.?!]* (for )?later|\b(a|the|for|in|into|to|until|next|later) v2\b|fold (it|that|them|this) in,? or |(left|kept) (it|them|that|this) out of (this|the) (pr|pull request)|(in|into|gets?|needs?) (its|their) own (pr|pull request)|(still want|should i (take|do|fix|build)|want me to (take|do|fix|build))[^.?!]*(#[0-9]+|(issue|ticket) #?[0-9]+)' \
  | grep -viE 'waits on|as you (said|asked)')
[ -n "$offers" ] || exit 0
jq -n --arg o "$offers" '{decision:"block", reason:("Never a V1: this effort ships complete. Fold this found work, and every open ticket here that waits on no one, into the current pull request now, then report what you folded in. Close open tickets before you open new ones: the summit is closing more than you open. Park only work that waits on the user'"'"'s decision, another person, a deploy or a repo out of reach, with a Waits on: line. A new behaviour no approved example names is noted for the user in one line, not filed as a ticket. The sentences:\n" + $o)}'
