#!/usr/bin/env bash
# Stop hook (guard_no_v1, off by default): an effort ships complete. In a
# session that started do or warp, when the agent's last reply offers found work as a follow-up pull request, a later
# ticket or a v2, keeps an open ticket out of the pull request, or asks
# whether to fold it in, leave it for later or take a ticket next, the
# stop is blocked once with a steer: fold it in, then report what was folded.
# A v2 counts only after a word such as "a" or "for", so a check labelled
# V2 is no offer, and code in backticks is dropped first. Ticket words match
# only as whole words, so "pr" inside "surprises" is no offer, and text in
# quotes, double or single, is a mention, dropped like code. A reply after
# the user asked for a separate pull request goes through. A sentence that
# names a wait (Waits on, waits on) or quotes the user (as you said) goes
# through. An offer to file or open a ticket for found work is stopped too.
# A reply that ends on a Next list naming no wait is sent back to
# start that list. It steers once per turn: with stop_hook_active set, the
# reply goes through, so a misjudged one never loops. The steer sends a new
# behaviour no approved example names to the repo's Ideas place: an "Ideas:"
# line in docs/agents/issue-tracker.md, else the place the user's own agent
# instructions name, else an Ideas section in the pull request body.
set -u
case "${CLAUDE_PLUGIN_OPTION_GUARD_NO_V1:-}" in true|1) ;; *) exit 0 ;; esac
# shellcheck source=stop-reply.sh
. "$(dirname "$0")/stop-reply.sh"
# Found work folds into an effort only while one is built. A session where do
# or warp never started is planning (filing tickets, a sup, a question), and
# its reply goes through.
grep -E '"skill": ?"(vicky-skills:)?(do|warp)"|<command-name>/(vicky-skills:)?(do|warp)</command-name>' "$transcript" | jq -e 'select(
  (.type == "assistant" and any(.message.content[]?; .type == "tool_use" and .name == "Skill" and (.input.skill | test("^(vicky-skills:)?(do|warp)$"))))
  or (.type == "user" and (.message.content | type) == "string" and (.message.content | test("<command-name>/(vicky-skills:)?(do|warp)</command-name>"))))' >/dev/null 2>&1 || exit 0
# A pull request of its own the user asked for is no deferral.
grep -qiE '\b(separate|different|own|new|another) (pr|pull request)\b' <<<"$asked" && exit 0
offers=$(prose | sed -E 's/"[^"]*"//g; s/“[^”]*”//g; s/‘[^’]*’//g; s/(^|[[:space:](])'"'"'[^'"'"']*'"'"'([[:space:].,;:!?)]|$)/\1\2/g' | tr '\n' ' ' | sed 's/\([.?!]\) /\1\n/g' \
  | grep -iE '\b(follow-?up|separate|another|later|future) (prs?|pull requests?|tickets?|issues?|efforts?|stars?)\b|\b(file|open)s?( it| that| this| them)?( as)? (a |an |its own |a new |a separate )(ticket|issue)\b|\b(ticket|pr|pull request|issue)\b[^.?!]* (for )?later|\b(a|the|for|in|into|to|until|next|later) v2\b|fold (it|that|them|this) in,? or |(left|kept) (it|them|that|this) out of (this|the) (pr|pull request)|(in|into|gets?|needs?) (its|their) own (pr|pull request)|(still want|should i (take|do|fix|build)|want me to (take|do|fix|build))[^.?!]*(#[0-9]+|(issue|ticket) #?[0-9]+)' \
  | grep -viE 'waits on|as you (said|asked)')
if [ -z "$offers" ]; then
  # A Next list that waits on no one is work to start, not to report. A Next
  # line that names a wait, a condition on someone else (once or until
  # with you, CI, a review, a deploy), asks, or ends a handoff the user
  # asked for goes through.
  grep -qE '(^|[[:space:]/:])conn([[:space:]]|$)' <<<"$asked" && exit 0
  # Only the turn's last message counts: a checkpoint's Next may be done by now.
  last=$(tail -n 400 "$transcript" | jq -rs '[.[] | select(.type == "assistant") | .message.content[]?
    | if .type == "text" then .text elif .type == "tool_use" and .name == "SendUserMessage" then .input.message else empty end] | last // ""' 2>/dev/null)
  next=$(sed 's/`[^`]*`//g' <<<"$last" | grep -iE '^[[:space:]*_-]*next( up)?[*_]*[:,]' | grep -v '?' | grep -viE 'wait|blocked|🚪|\b(merges?|to you)\b|\b(once|until)\b[^.]*\b(you|your|ci|checks?|green|approv[a-z]*|deploy[a-z]*|review[a-z]*|lands?)\b')
  [ -n "$next" ] || exit 0
  jq -n --arg n "$next" '{decision:"block", reason:("Your reply ends on a Next list that waits on no one, so it is work to do now, not to report. Start its first item in this turn and keep going until each item is done or waits on the user, another person or a deploy. Review findings inside an effort are part of it: fix each one that waits on no one, then report. The line:\n" + $n)}'
  exit 0
fi
# The Ideas place: the "Ideas:" line in the repo's tracker file, else the one the
# user's own agent instructions name, else the pull request body.
ideas=$(sed -n 's/^Ideas: //p' "${CLAUDE_PROJECT_DIR:-.}/docs/agents/issue-tracker.md" 2>/dev/null | head -n 1)
where="the Ideas place, $ideas,"
[ -n "$ideas" ] || where="the Ideas place your own agent instructions name, else in an Ideas section of the pull request body,"
jq -n --arg o "$offers" --arg i "$where" '{decision:"block", reason:("Never a V1: this effort ships complete. Fold this found work, and every open ticket here that waits on no one, into the current pull request now, then report what you folded in. Close open tickets before you open new ones: the summit is closing more than you open. Park only work that waits on the user'"'"'s decision, another person, a deploy or a repo out of reach, with a Waits on: line. A new behaviour no approved example names is no ticket and no build: write it as one line in " + $i + " and say where it went. The sentences:\n" + $o)}'
