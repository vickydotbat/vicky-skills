# skill_started <transcript> <skill>: true when the session started the skill,
# by the agent's Skill call or the user's typed /<skill>. A typed command
# arrives as a plain string prompt; a tool result never does, so text that
# only quotes the marker never counts. Sourced by draft-guard.sh and
# ticket-filing-guard.sh.
skill_started() {
  jq -r --arg s "$2" 'if .type == "assistant" then (.message.content[]? | select(.type == "tool_use" and .name == "Skill") | (.input.skill // "") | sub("^[A-Za-z0-9_-]+:"; ""))
    elif .type == "user" then (.message.content | strings | select(test("<command-name>/([A-Za-z0-9_-]+:)?" + $s + "</command-name>")) | $s)
    else empty end' "$1" 2>/dev/null | grep -qxF -- "$2"
}
