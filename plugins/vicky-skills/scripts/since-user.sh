# shellcheck shell=bash
# Sourced by hooks that ask what happened since the user's last real message
# (todo-guard, todo-next, publish-guard, stop-reply). Claude Code injects skill text and hook feedback as
# user messages marked isMeta, so those never count as the user speaking.
# skill_since_user <transcript> <skill> exits 0 when that skill started since.
skill_since_user() {
  [ "$(tail -n 400 "$1" | jq -rs --arg s "$2" '
    (map(.type == "user" and (.isMeta | not) and ((.message.content | type) == "string" or any(.message.content[]?; .type == "text"))) | rindex(true)) as $u
    | [.[(($u // -1) + 1):][] | select(.type == "assistant") | .message.content[]? | select(.type == "tool_use")
       | select(.name == "Skill" and ((.input.skill // "") | test("(^|:)" + $s + "$")))] | length' 2>/dev/null)" -gt 0 ] 2>/dev/null
}
# last_user_message <transcript> prints the user's last typed message.
last_user_message() {
  tail -n 400 "$1" 2>/dev/null | jq -rs '
    [.[] | select(.type == "user" and (.isMeta | not)) | .message.content
     | if type == "string" then . else ([.[]? | select(.type == "text") | .text] | join(" ")) end
     | select(. != "")] | last // ""' 2>/dev/null
}
# council_sits <transcript> exits 0 while a council-of-elrond sits: it started,
# and no Frodo line came in a turn before this one. The reply that holds
# Frodo's line still counts as sitting: it closes the council.
council_sits() {
  [ "$(tail -n 400 "$1" 2>/dev/null | jq -rs '
    (map(.type == "user" and (.isMeta | not) and ((.message.content | type) == "string" or any(.message.content[]?; .type == "text"))) | rindex(true)) as $u
    | (map(.type == "assistant" and any(.message.content[]?; .type == "tool_use" and .name == "Skill" and ((.input.skill // "") | test("(^|:)council-of-elrond$")))) | rindex(true)) as $c
    | if $c == null then 0
      else [.[($c + 1):($u // 0)][] | select(.type == "assistant") | .message.content[]?
        | if .type == "text" then .text elif .type == "tool_use" and .name == "SendUserMessage" then .input.message else empty end
        | select(test("\\*\\*Frodo:\\*\\*"))] | if length == 0 then 1 else 0 end end' 2>/dev/null)" = 1 ]
}
