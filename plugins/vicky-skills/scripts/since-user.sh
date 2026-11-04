# shellcheck shell=bash
# Sourced by hooks that ask what happened since the user's last real message
# (todo-guard, todo-next). Claude Code injects skill text and hook feedback as
# user messages marked isMeta, so those never count as the user speaking.
# skill_since_user <transcript> <skill> exits 0 when that skill started since.
skill_since_user() {
  [ "$(tail -n 400 "$1" | jq -rs --arg s "$2" '
    (map(.type == "user" and (.isMeta | not) and ((.message.content | type) == "string" or any(.message.content[]?; .type == "text"))) | rindex(true)) as $u
    | [.[(($u // -1) + 1):][] | select(.type == "assistant") | .message.content[]? | select(.type == "tool_use")
       | select(.name == "Skill" and ((.input.skill // "") | test("(^|:)" + $s + "$")))] | length' 2>/dev/null)" -gt 0 ] 2>/dev/null
}
