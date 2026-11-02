#!/usr/bin/env bash
# approved-spec: the quoted-loop examples, approved 2026-11-02. poll-pace
# reads a loop inside quotes or a heredoc no shell runs as text, and a quoted
# loop handed to a shell as code.
set -u
hook="$(dirname "$0")/../plugins/vicky-skills/scripts/poll-pace.sh"
fail=0
run() { printf '%s' "$1" | jq -Rs '{tool_name: "Bash", tool_input: {command: .}}' | CLAUDE_PLUGIN_OPTION_GUARD_POLL_PACE=true bash "$hook" >/dev/null 2>&1; echo $?; }
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
loop='for i in 1 2 3; do grep -q READY log && break; sleep 5; done'

# Given an agent that writes a sleeping loop into a file or a message, inside quotes or a heredoc no shell runs
# When it runs that command
# Then the command goes through
check "a loop written as text is not a loop" '[ "$(run "printf %s '"'"'$loop'"'"' > case.txt")" = 0 ] && [ "$(run "jq -n --arg c \"$loop\" .")" = 0 ] && [ "$(run "python3 - <<'"'"'PY'"'"'
open(\"case.txt\", \"w\").write(\"$loop\")
PY")" = 0 ]'

# Given an agent that runs a sleeping loop through bash -c, inside single quotes
# When it runs that command in the foreground
# Then the command is refused, as before
check "a quoted loop a shell runs still stops" '[ "$(run "bash -c '"'"'$loop'"'"'")" = 2 ] && [ "$(run "sh -c \"$loop\"")" = 2 ] && [ "$(run "$loop")" = 2 ]'
exit $fail
