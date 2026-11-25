# skill_started <transcript> <skill> [agent_id]: true when the session started
# the skill, by the agent's Skill call or the user's typed /<skill>. A typed
# command arrives as a plain string prompt; a tool result never does, so text
# that only quotes the marker never counts. Sourced by draft-guard.sh,
# rebase-guard.sh and ticket-filing-guard.sh.
# Inside a subagent the hook payload's transcript_path is still the parent's
# transcript, and the subagent's own turns go to
# <transcript without .jsonl>/subagents/agent-<agent_id>.jsonl. Given the
# payload's agent_id, a Skill call in that file counts too. Its plain string
# prompt is the parent agent's task, never the user's typing, so only its Skill
# calls are read. Each file gets its own jq run, and each line is parsed on its
# own, so a torn line (NUL bytes from a crash) is skipped and hides no later call.
skill_started() {
  local sub="" calls='.message.content[]? | select(.type == "tool_use" and .name == "Skill") | (.input.skill // "") | sub("^[A-Za-z0-9_-]+:"; "")'
  case "${3:-}" in
    "" | *[!A-Za-z0-9_-]*) ;;
    *) sub="${1%.jsonl}/subagents/agent-$3.jsonl" ;;
  esac
  {
    jq -Rr --arg s "$2" "fromjson? | if .type == \"assistant\" then ($calls)
      elif .type == \"user\" then (.message.content | strings | select(test(\"<command-name>/([A-Za-z0-9_-]+:)?\" + \$s + \"</command-name>\")) | \$s)
      else empty end" "$1"
    [ -z "$sub" ] || jq -Rr "fromjson? | select(.type == \"assistant\") | $calls" "$sub"
  } 2>/dev/null | grep -qxF -- "$2"
}

# agent_of <payload>: the payload's agent_id, empty outside a subagent.
agent_of() { jq -r '.agent_id // ""' <<<"$1" 2>/dev/null; }
