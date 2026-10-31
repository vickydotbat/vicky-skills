#!/usr/bin/env bash
# scratch-guard gives each subagent its own folder, refuses a subagent's call
# that names the shared session folder, and passes everything else.
set -u
hook="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/scratch-guard.sh"
sid="scratch-guard-test-$$"
agent=test-agent
trap 'rm -rf "/tmp/$sid"' EXIT
fail=0
# $1 tool_input, $2 agent_id ("" for the main thread), $3 the option.
run() {
  jq -nc --arg s "$sid" --arg a "$2" --argjson i "$1" '{hook_event_name: "PreToolUse", session_id: $s, agent_id: $a, tool_input: $i}' |
    CLAUDE_PLUGIN_OPTION_GUARD_SCRATCH="${3-true}" bash "$hook" >/dev/null 2>&1
  echo $?
}
cmd() { jq -nc --arg c "$1" '{command: $c}'; }
file() { jq -nc --arg f "$1" '{file_path: $f, content: "x"}'; }
expect() { # name want got
  if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: exit $3, want $2"; fail=1; fi
}

expect "a write to the shared folder is refused" 2 "$(run "$(cmd "echo body > /tmp/$sid/pr-body.md")" $agent)"
expect "the variable spelling is refused" 2 "$(run "$(cmd 'echo body > /tmp/$CLAUDE_CODE_SESSION_ID/pr-body.md')" $agent)"
expect "the braced variable spelling is refused" 2 "$(run "$(cmd 'echo body > /tmp/${CLAUDE_CODE_SESSION_ID}/pr-body.md')" $agent)"
expect "the bare shared folder is refused" 2 "$(run "$(cmd 'mkdir -p /tmp/$CLAUDE_CODE_SESSION_ID')" $agent)"
expect "a Write to the shared folder is refused" 2 "$(run "$(file "/tmp/$sid/body.md")" $agent)"
expect "the shared folder before a semicolon is refused" 2 "$(run "$(cmd "D=/tmp/$sid; ls \"\$D\"")" $agent)"
expect "the shared folder in a command substitution is refused" 2 "$(run "$(cmd "x=\$(cat /tmp/$sid/out)")" $agent)"
expect "a sibling's folder is refused" 2 "$(run "$(cmd "cat /tmp/$sid/other-agent/out")" $agent)"

expect "its own folder passes" 0 "$(run "$(cmd "echo body > /tmp/$sid/$agent/pr-body.md")" $agent)"
expect "a Write to its own folder passes" 0 "$(run "$(file "/tmp/$sid/$agent/body.md")" $agent)"
expect "its own folder in a variable passes" 0 "$(run "$(cmd "D=/tmp/$sid/$agent; ls \"\$D\"")" $agent)"
expect "a cd into its own folder passes" 0 "$(run "$(cmd "cd /tmp/$sid/$agent && ls")" $agent)"
expect "a glob in its own folder passes" 0 "$(run "$(cmd "ls /tmp/$sid/$agent/*.txt")" $agent)"
expect "its own folder in a command substitution passes" 0 "$(run "$(cmd "x=\$(cat /tmp/$sid/$agent/a)")" $agent)"
expect "its own folder by the variable, before a semicolon, passes" 0 "$(run "$(cmd "ls /tmp/\$CLAUDE_CODE_SESSION_ID/$agent;")" $agent)"
expect "text that only quotes the shared folder passes" 0 "$(run "$(jq -nc --arg f "/tmp/$sid/$agent/n.md" --arg c "see /tmp/$sid/pr-body.md" '{file_path: $f, content: $c}')" $agent)"
expect "the main thread owns the session folder" 0 "$(run "$(cmd "echo body > /tmp/$sid/pr-body.md")" "")"
expect "another session's folder passes" 0 "$(run "$(cmd 'echo x > /tmp/other-session/pr-body.md')" $agent)"
expect "off when the option is off" 0 "$(run "$(cmd "echo body > /tmp/$sid/pr-body.md")" $agent false)"
expect "option 1 counts as on" 2 "$(run "$(cmd "echo body > /tmp/$sid/pr-body.md")" $agent 1)"

err=$(jq -nc --arg s "$sid" --arg a "$agent" --argjson i "$(cmd "cat /tmp/$sid/out")" '{hook_event_name: "PreToolUse", session_id: $s, agent_id: $a, tool_input: $i}' |
  CLAUDE_PLUGIN_OPTION_GUARD_SCRATCH=true bash "$hook" 2>&1 >/dev/null)
out=$(jq -nc --arg s "$sid" --arg a "$agent" --argjson i "$(cmd "cat /tmp/$sid/out")" '{hook_event_name: "PreToolUse", session_id: $s, agent_id: $a, tool_input: $i}' |
  CLAUDE_PLUGIN_OPTION_GUARD_SCRATCH=true bash "$hook" 2>/dev/null)
{ grep -q "^scratch-guard: refused" <<<"$err" && grep -qF "  /tmp/$sid/out" <<<"$err" && grep -qF "own folder instead: /tmp/$sid/$agent" <<<"$err" && [ -z "$out" ]; } &&
  echo "ok   the refusal, on stderr, names the shared path and the agent's own folder" || { echo "FAIL refusal text: '$err' / stdout '$out'"; fail=1; }
got=$(printf 'not json' | CLAUDE_PLUGIN_OPTION_GUARD_SCRATCH=true bash "$hook" 2>/dev/null; echo $?)
expect "input that is not JSON passes" 0 "$got"
start=$(jq -nc --arg s "$sid" --arg a "$agent" '{hook_event_name: "SubagentStart", session_id: $s, agent_id: $a}' |
  CLAUDE_PLUGIN_OPTION_GUARD_SCRATCH=true bash "$hook"); code=$?
expect "SubagentStart exits 0" 0 "$code"
[ -d "/tmp/$sid/$agent" ] && echo "ok   SubagentStart makes the folder" || { echo "FAIL SubagentStart made no folder"; fail=1; }
jq -e --arg d "/tmp/$sid/$agent" '.hookSpecificOutput.hookEventName == "SubagentStart" and (.hookSpecificOutput.additionalContext | contains($d))' <<<"$start" >/dev/null 2>&1 &&
  echo "ok   SubagentStart names the folder" || { echo "FAIL SubagentStart context: '$start'"; fail=1; }
nostart=$(jq -nc --arg s "$sid" '{hook_event_name: "SubagentStart", session_id: $s, agent_id: ""}' | CLAUDE_PLUGIN_OPTION_GUARD_SCRATCH=true bash "$hook")
expect "SubagentStart with no agent id says nothing" "" "$nostart"
bin=$(mktemp -d); for t in bash cat; do ln -s "$(command -v $t)" "$bin/$t"; done
got=$(cmd "echo body > /tmp/$sid/pr-body.md" | jq -c --arg s "$sid" --arg a "$agent" '{hook_event_name: "PreToolUse", session_id: $s, agent_id: $a, tool_input: .}' |
  PATH="$bin" CLAUDE_PLUGIN_OPTION_GUARD_SCRATCH=true "$(command -v bash)" "$hook" 2>/dev/null; echo $?)
rm -rf "$bin"
expect "without jq it stays quiet" 0 "$got"
exit $fail
