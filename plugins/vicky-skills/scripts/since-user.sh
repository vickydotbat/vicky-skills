# shellcheck shell=bash
# Sourced by hooks that ask what happened since the user's last real message
# (publish-guard). Claude Code injects skill text and hook feedback as
# user messages marked isMeta, so those never count as the user speaking.
# last_user_message <transcript> prints the user's last typed message.
last_user_message() {
  tail -n 400 "$1" 2>/dev/null | jq -rs '
    [.[] | select(.type == "user" and (.isMeta | not)) | .message.content
     | if type == "string" then . else ([.[]? | select(.type == "text") | .text] | join(" ")) end
     | select(. != "")] | last // ""' 2>/dev/null
}
