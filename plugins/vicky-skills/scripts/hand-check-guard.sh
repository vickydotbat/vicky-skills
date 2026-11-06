#!/usr/bin/env bash
# Stop hook (guard_hand_check, on by default): a live check only the user can do
# goes to them through `over-to-you`, never as steps in chat. When the agent's
# last reply tells the user to try, test or check something themselves in the
# game, the client or the browser, holds no link to a page on this machine, and
# the session never started `over-to-you`, the stop is blocked once with a steer
# to hand the checks over with it. A reply that reports tests, a reply with a
# page link, a session that already ran `over-to-you` and the setting off go
# through. It steers once per turn: with stop_hook_active set, the reply goes
# through, so a misjudged one never loops.
set -u
case "${CLAUDE_PLUGIN_OPTION_GUARD_HAND_CHECK:-}" in false|0) exit 0 ;; esac
# shellcheck source=stop-reply.sh
. "$(dirname "$0")/stop-reply.sh"
grep -qE "https?://(127\.0\.0\.1|localhost)[:/]" <<<"$said" && exit 0
words=$(prose)
grep -qiE '\b(you (can|could|should)|please|now) (try|test|check|play)\b|\b(try|test|check) (it|this|that|them) (out|yourself|in)\b' <<<"$words" || exit 0
grep -qiE '\bin[- ]game\b|\bthe (game )?client\b|\byour browser\b|\bin the (game|browser)\b|\breal (client|browser|hardware)\b' <<<"$words" || exit 0
grep -q '"skill":"[^"]*over-to-you"' "$transcript" && exit 0
jq -n '{decision:"block", reason:"You told the user to try or test something themselves in chat. A check only a person can do goes to them through the over-to-you skill: a checklist page with its kits, its stage proven up, and the page link in your reply. Start over-to-you now."}'
