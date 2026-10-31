#!/usr/bin/env bash
# The hook refuses a poll slower than every 30 seconds or longer than 60
# rounds, and only when switched on.
set -u
hook="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/poll-pace.sh"
fail=0
expect() { # $1 want, $2 option, $3 label, $4 command
  local got
  got=$(jq -nc --arg c "$4" '{tool_input:{command:$c}}' |
    CLAUDE_PLUGIN_OPTION_GUARD_POLL_PACE=$2 "$hook" >/dev/null 2>&1; echo $?)
  if [ "$got" = "$1" ]; then echo "ok   $3"; else echo "FAIL $3: want $1, got $got"; fail=1; fi
}
expect 0 true "a 30-second poll, 60 rounds, passes" 'for i in $(seq 1 60); do test -f x && exit; sleep 30; done'
expect 2 true "a 31-second sleep is refused" 'sleep 31'
expect 2 true "a 60-second poll is refused" 'for i in $(seq 1 60); do sleep 60; done'
expect 2 true "a loop of 61 rounds is refused" 'for i in $(seq 1 61); do sleep 30; done'
expect 2 true "a brace loop of 61 rounds is refused" 'for i in {1..61}; do sleep 5; done'
expect 0 true "a long seq with no sleep is not a poll" 'seq 1 500 | wc -l'
expect 0 false "switched off, a 60-second sleep passes" 'sleep 60'
exit $fail
