#!/usr/bin/env bash
# Stop hook (guard_idle_stop, on by default): an agent never sits idle unless
# it waits at a gate. A turn that did work since the user's last message may
# end only when its last reply opens with "🚪 Waiting on you:" (a gate) or
# "🏁 Done:" (the work is finished), when it asked through AskUserQuestion, or
# when it left something running that wakes the session: a background Agent,
# a Bash call with run_in_background, or a Monitor. A turn that only replied
# ends as usual, and so does a turn woken by a background notice that wrote no
# reply. Any other stop is sent back once with a steer to make the
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
# A task started in an earlier turn and still running wakes the session too.
# Its id shows in its start result (agentId, background Bash ID, Monitor task)
# and leaves the running set when a notice carries that id and a status.
recent=$(tail -n 400 "$transcript")
started=$(grep -oE 'agentId: [a-z0-9]+|running in background with ID: [a-z0-9]+|Monitor started \(task [a-z0-9]+' <<<"$recent" | grep -oE '[a-z0-9]+$' | sort -u)
ended=$(grep -oE '<task-id>[a-z0-9]+</task-id>(\\n|[^<])*(<[a-z-]+>[^<]*</[a-z-]+>(\\n|[^<])*)*<status>' <<<"$recent" | grep -oE '<task-id>[a-z0-9]+' | cut -d'>' -f2 | sort -u)
[ -n "$(comm -23 <(printf '%s\n' "$started") <(printf '%s\n' "$ended") | grep .)" ] && exit 0
last=$(jq -r '[.[] | if .type == "text" then .text elif .type == "tool_use" and .name == "SendUserMessage" then .input.message else empty end | select(test("\\S"))] | last // ""' <<<"$turn")
# A turn woken by a background notice (a monitor event or a subagent result)
# that wrote no reply has nothing to report, so it ends silent.
began=$(tail -n 400 "$transcript" | jq -rs '(map(.type == "user" and (.isMeta | not) and ((.message.content | type) == "string" or any(.message.content[]?; .type == "text"))) | rindex(true)) as $u | if $u == null then "" else (.[$u].origin.kind // "") end' 2>/dev/null)
[[ "$began" == task-notification && -z "$last" ]] && exit 0
first=$(sed -n '/[^[:space:]]/{p;q}' <<<"$last")
first="${first#"${first%%[![:space:]]*}"}"
[[ "$first" == '🚪 Waiting on you:'* || "$first" == '🏁 Done:'* ]] && exit 0
jq -n '{decision:"block", reason:"This turn did work and is ending with no gate and no done line, so an AFK user would come back to an idle session. Make the next step'"'"'s tool call now. If the work is finished, send a reply whose first line is \"🏁 Done: <what landed>\". If it waits on the user, open the reply with \"🚪 Waiting on you: <the one thing>\" and wait with a watch."}'
