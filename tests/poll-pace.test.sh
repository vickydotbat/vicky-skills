#!/usr/bin/env bash
# The hook refuses a foreground poll loop, a poll slower than every 30
# seconds or longer than 60 rounds, and only when switched on.
set -u
hook="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/poll-pace.sh"
fail=0
expect() { # $1 want, $2 option, $3 label, $4 command, $5 run in background
  local got
  got=$(jq -nc --arg c "$4" --argjson bg "${5:-false}" '{tool_input:{command:$c, run_in_background:$bg}}' |
    CLAUDE_PLUGIN_OPTION_GUARD_POLL_PACE=$2 "$hook" >/dev/null 2>&1; echo $?)
  if [ "$got" = "$1" ]; then echo "ok   $3"; else echo "FAIL $3: want $1, got $got"; fail=1; fi
}
expect 0 true "a 30-second poll, 60 rounds, in the background passes" 'for i in $(seq 1 60); do test -f x && exit; sleep 30; done' true
expect 2 true "the same poll in the foreground is refused" 'for i in $(seq 1 60); do test -f x && exit; sleep 30; done'
expect 0 true "a single short sleep passes" 'sleep 5'
expect 2 true "a 31-second sleep is refused" 'sleep 31'
expect 2 true "a 60-second poll is refused" 'for i in $(seq 1 60); do sleep 60; done' true
expect 2 true "a loop of 61 rounds is refused" 'for i in $(seq 1 61); do sleep 30; done' true
expect 2 true "a brace loop of 61 rounds is refused" 'for i in {1..61}; do sleep 5; done' true
expect 0 true "a long seq with no sleep is not a poll" 'seq 1 500 | wc -l'
expect 2 true "a loop run by eval is refused" "eval 'while true; do sleep 5; done'"
expect 2 true "a loop run by zsh -c is refused" "zsh -c 'while true; do sleep 5; done'"
expect 2 true "a long sleep inside a watch.sh check is refused" "watch.sh 'sleep 31; true'"
expect 0 true "a long sleep quoted in a commit message passes" 'git commit -m "wait out a sleep 60 loop"'
expect 2 true "a loop after a quoted word is still read" "echo 'go'; while true; do sleep 5; done"
expect 0 true "a loop in a python heredoc is text" "$(printf "python3 - <<'PY'\nprint('while true; do sleep 5; done')\nPY")"
expect 0 true "a quoted sleep beside an eval of something else passes" 'echo "sleep 60"; eval x'
expect 2 true "a loop run by bash -c in double quotes is refused" 'bash -c "while true; do sleep 5; done"'
expect 0 true "a quote spliced into a string leaves its words as text" "sed -i 's/it'\"'\"'s asks for those steps/x/' f && sleep 15 && gh run list"
expect 2 true "a real loop after a spliced quote is still refused" "sed -i 's/it'\"'\"'s/x/' f; while true; do sleep 5; done"
expect 2 true "an unclosed quote is read as it stands" "echo 'oops; while true; do sleep 5; done"
expect 0 false "switched off, a 60-second sleep passes" 'sleep 60'
exit $fail
