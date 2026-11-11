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
expectm() { # $1 want, $2 label, $3 command: the Monitor tool runs it in the background
  local got
  got=$(jq -nc --arg c "$3" '{tool_name:"Monitor", tool_input:{command:$c}}' |
    CLAUDE_PLUGIN_OPTION_GUARD_POLL_PACE=true "$hook" >/dev/null 2>&1; echo $?)
  if [ "$got" = "$1" ]; then echo "ok   $2"; else echo "FAIL $2: want $1, got $got"; fail=1; fi
}
expectm 0 "a 60-round poll under the Monitor tool passes, since Monitor runs in the background" 'for i in $(seq 1 60); do test -f x && exit; sleep 5; done'
expectm 0 "a 300-round poll under the Monitor tool goes through, since Monitor times it out" 'for i in $(seq 1 300); do test -f x && exit; sleep 5; done'
got=$(jq -nc '{tool_name:"Bash", tool_input:{command:"for i in 1 2; do echo x; sleep 1; done", timeout_ms:10000}}' | CLAUDE_PLUGIN_OPTION_GUARD_POLL_PACE=true "$hook" >/dev/null 2>&1; echo $?)
[ "$got" = 0 ] && echo "ok   a Monitor call that arrives as Bash, marked by timeout_ms, passes" || { echo "FAIL a Monitor call that arrives as Bash: got $got"; fail=1; }
expect 0 true "a 30-second poll, 60 rounds, in the background passes" 'for i in $(seq 1 60); do test -f x && exit; sleep 30; done' true
expect 2 true "the same poll in the foreground is refused" 'for i in $(seq 1 60); do test -f x && exit; sleep 30; done'
expect 0 true "a single short sleep passes" 'sleep 5'
w='bash watch.sh "grep -q end_turn /tmp/x/tasks/a15f2707f785bbbc2.output"'
expectm 2 "a Monitor watch on a subagent's output file is refused" "$w"
expect 2 true "a background watch on a subagent's output file is refused" "$w" true
expect 2 true "a read of a subagent's output file is refused" 'tail -3 /tmp/x/tasks/a15f2707f785bbbc2.output'
expect 0 true "a watch on a background command's output file passes" 'bash watch.sh "grep -q exit= /tmp/x/tasks/b8aqlwi7h.output"' true
expect 0 false "a watch on a subagent's output file passes with the setting off" "$w"
expect 2 true "a 31-second sleep is refused" 'sleep 31'
expect 0 true "a 60-second poll in the background goes through" 'for i in $(seq 1 60); do sleep 60; done' true
expect 0 true "a background loop of 61 rounds goes through" 'for i in $(seq 1 61); do sleep 30; done' true
expect 0 true "a background brace loop of 61 rounds goes through" 'for i in {1..61}; do sleep 5; done' true
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
expect 0 true "a bash -c quoted inside a sed text leaves the text quoted" "sed -i 's|sleep 300 \\& dead|dead=\$(bash -c '\"'\"'echo \$\$'\"'\"')|' f"
expect 2 true "a real loop after a spliced quote is still refused" "sed -i 's/it'\"'\"'s/x/' f; while true; do sleep 5; done"
expect 2 true "an unclosed quote is read as it stands" "echo 'oops; while true; do sleep 5; done"
expect 0 false "switched off, a 60-second sleep passes" 'sleep 60'
exit $fail
