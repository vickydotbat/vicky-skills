# skill_started <transcript> <skill> [agent_id]: true when the session started
# the skill, by the agent's Skill call or the user's typed /<skill>. A typed
# command arrives as a plain string prompt; a tool result never does, so text
# that only quotes the marker never counts. Sourced by draft-guard.sh,
# rebase-guard.sh and ticket-filing-guard.sh.
# Inside a subagent the hook payload's transcript_path is still the parent's
# transcript, and the subagent's own turns go to
# <transcript without .jsonl>/subagents/agent-<agent_id>.jsonl. Given the
# payload's agent_id, a Skill call in either file counts.
skill_started() {
  local files=("$1")
  case "${3:-}" in
    "" | *[!A-Za-z0-9_-]*) ;;
    *) files+=("${1%.jsonl}/subagents/agent-$3.jsonl") ;;
  esac
  jq -r --arg s "$2" 'if .type == "assistant" then (.message.content[]? | select(.type == "tool_use" and .name == "Skill") | (.input.skill // "") | sub("^[A-Za-z0-9_-]+:"; ""))
    elif .type == "user" then (.message.content | strings | select(test("<command-name>/([A-Za-z0-9_-]+:)?" + $s + "</command-name>")) | $s)
    else empty end' "${files[@]}" 2>/dev/null | grep -qxF -- "$2"
}

# agent_of <payload>: the payload's agent_id, empty outside a subagent.
agent_of() { jq -r '.agent_id // ""' <<<"$1" 2>/dev/null; }
