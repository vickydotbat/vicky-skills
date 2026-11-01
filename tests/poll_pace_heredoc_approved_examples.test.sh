#!/usr/bin/env bash
# approved-spec: the examples approved for S2 (F7). poll-pace reads a heredoc
# written to a file as text, and a heredoc fed to a shell as code.
set -u
hook="$(dirname "$0")/../plugins/vicky-skills/scripts/poll-pace.sh"
fail=0
run() { printf '%s' "$1" | jq -Rs '{tool_name: "Bash", tool_input: {command: .}}' | CLAUDE_PLUGIN_OPTION_GUARD_POLL_PACE=true bash "$hook" 2>/dev/null; echo $?; }
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got '$3', want '$2'"; fail=1; fi; }
loop='while true; do sleep 5; done'

# Given poll-pace is on
# When a command writes a heredoc to a file, and the heredoc's text holds a loop that sleeps
# Then the command runs
check "a heredoc written to a file passes" 0 "$(run "cat > notes.md <<'EOF'
$loop
EOF")"

# Given poll-pace is on
# When a command feeds a heredoc holding a loop that sleeps to bash
# Then poll-pace refuses it
check "a heredoc fed to bash is refused" 2 "$(run "bash <<'EOF'
$loop
EOF")"
exit $fail
