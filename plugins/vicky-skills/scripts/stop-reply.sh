# shellcheck shell=bash
# Sourced by the Stop hooks that read the agent's last reply (take-pick,
# no-v1). Reads the hook's payload from stdin. Exits 0, letting the stop
# through, on the second stop of a turn, so a misjudged reply never loops, and
# when the transcript is missing. Leaves `said`, the agent's text since the
# user's last typed message: its chat text and the messages it sent with
# SendUserMessage. `prose` prints it with code in backticks dropped, since
# quoted code is text the reply talks about, never its own words.
payload=$(cat)
[ "$(jq -r '.stop_hook_active // false' <<<"$payload" 2>/dev/null)" = false ] || exit 0
transcript=$(jq -r '.transcript_path // ""' <<<"$payload" 2>/dev/null)
[ -f "$transcript" ] || exit 0 # mutant-ok delete: tail reads nothing from a missing file, so the reply reads empty and each hook exits 0
# shellcheck disable=SC2034 # read by the hook that sources this
said=$(tail -n 400 "$transcript" | jq -rs '
  (map(.type == "user" and (.isMeta | not) and ((.message.content | type) == "string" or any(.message.content[]?; .type == "text"))) | rindex(true)) as $u
  | .[(($u // -1) + 1):][] | select(.type == "assistant") | .message.content[]?
  | if .type == "text" then .text elif .type == "tool_use" and .name == "SendUserMessage" then .input.message else empty end' 2>/dev/null)
prose() { sed 's/`[^`]*`//g' <<<"$said"; }
# The user's last typed message, for a hook that weighs the reply against it.
. "$(dirname "${BASH_SOURCE[0]}")/since-user.sh"
# shellcheck disable=SC2034 # read by the hook that sources this
asked=$(last_user_message "$transcript")
