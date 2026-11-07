#!/usr/bin/env bash
# Stop hook (guard_idle_stop, on by default): an agent never sits idle unless
# it waits at a gate. A turn that did work since the user's last message may
# end only when its last reply opens with "🚪 Waiting on you:" (a gate) or
# "🏁 Done:" (the work is finished), when it asked through AskUserQuestion, or
# when it left something running that wakes the session: a background Agent,
# a Bash call with run_in_background, or a Monitor. A turn that only replied
# ends as usual. Any other stop is sent back once with a steer to make the
# next step's tool call. It reads declared state (the reply's first line and
# the turn's tool calls), never what the words seem to mean. With
# stop_hook_active set, the stop goes through, so a misjudged one never loops.
set -u
case "${CLAUDE_PLUGIN_OPTION_GUARD_IDLE_STOP:-}" in false|0) exit 0 ;; esac
command -v jq >/dev/null || exit 0 # mutant-ok delete: without the tool every later read comes back empty, and the hook exits 0 the same way
# shellcheck source=stop-reply.sh
. "$(dirname "$0")/stop-reply.sh"
# A turn that only replied did no work, so it may end.
jq -e 'any(.[]; .type == "tool_use" and .name != "SendUserMessage")' <<<"$turn" >/dev/null || exit 0
# A question asked or something left running that wakes the session.
jq -e 'any(.[]; .type == "tool_use" and (.name == "AskUserQuestion" or .name == "Monitor" or .name == "Agent" or .input.run_in_background == true))' <<<"$turn" >/dev/null && exit 0
last=$(jq -r '[.[] | if .type == "text" then .text elif .type == "tool_use" and .name == "SendUserMessage" then .input.message else empty end | select(test("\\S"))] | last // ""' <<<"$turn")
first=$(sed -n '/[^[:space:]]/{p;q}' <<<"$last")
first="${first#"${first%%[![:space:]]*}"}"
[[ "$first" == '🚪 Waiting on you:'* || "$first" == '🏁 Done:'* ]] && exit 0
jq -n '{decision:"block", reason:"This turn did work and is ending with no gate and no done line, so an AFK user would come back to an idle session. Make the next step'"'"'s tool call now. If the work is finished, send a reply whose first line is \"🏁 Done: <what landed>\". If it waits on the user, open the reply with \"🚪 Waiting on you: <the one thing>\" and wait with a watch."}'
