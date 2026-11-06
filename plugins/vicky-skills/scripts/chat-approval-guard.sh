#!/usr/bin/env bash
# Stop hook (guard_chat_approval, on by default): approval is a tick on a page,
# never a chat reply, however small a formality it looks. When the agent's last
# reply asks the user to approve, confirm or give an "ok" for examples, a spec
# or text for an audience, and holds no link to a page, the stop is blocked once
# with a steer: hand the text over with `red-pen`. A reply with a page link, a
# plain pick between options and the setting off go through. It steers once per
# turn: with stop_hook_active set, the reply goes through, so a misjudged one
# never loops. A pick is take-pick's, so a reply that names no examples, spec or
# text is no business of this hook.
set -u
case "${CLAUDE_PLUGIN_OPTION_GUARD_CHAT_APPROVAL:-}" in false|0) exit 0 ;; esac
# shellcheck source=stop-reply.sh
. "$(dirname "$0")/stop-reply.sh"
# The page is where the tick is asked: a link to a page on this machine. Any other link is no page.
grep -qE "https?://(127\.0\.0\.1|localhost)[:/]" <<<"$said" && exit 0
words=$(prose)
grep -qiE '\bapprove\b|\bconfirm (the|these|this|it|them)\b|\byour (ok|approval)\b|\b(reply|say) (ok|yes|go)\b|\btick (the|these|this|it|them|each)\b' <<<"$words" || exit 0
grep -qiE '\b(examples?|spec|wording|drafts?|text for|credits row|release notes)\b' <<<"$words" || exit 0
jq -n '{decision:"block", reason:"You asked the user to approve examples, a spec or text for an audience in chat. Approval is a tick on a page, never a chat reply, however small a formality it looks. Write the text into a red-pen draft file with its approve ticks, open it, give the page link, and wait at the gate with a watch."}'
