#!/usr/bin/env bash
# The ticket-filing guard: a command that files a ticket (plane file, tea issues
# create, gh issue create) is refused until the session has started
# mission-brief. Every other command, a quoted mention, the setting off, a
# missing transcript and bad input pass.
set -u
guard="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/ticket-filing-guard.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
fail=0
started() { jq -nc --arg s "$1" '{type:"assistant",message:{content:[{type:"tool_use",name:"Skill",input:{skill:$s}}]}}'; }
started vicky-skills:do > "$dir/none.jsonl"
{ started vicky-skills:do; started vicky-skills:mission-brief; } > "$dir/briefed.jsonl"
expect() { # name want transcript command [env...]
  local name=$1 want=$2 transcript=$3 cmd=$4; shift 4
  jq -nc --arg c "$cmd" --arg t "$transcript" '{tool_input:{command:$c},transcript_path:$t}' |
    env CLAUDE_PLUGIN_OPTION_GUARD_TICKET_FILING=true "$@" "$guard" >"$dir/out" 2>"$dir/err"; got=$?
  if [ "$got" = "$want" ]; then echo "ok   $name"; else echo "FAIL $name: exit $got, want $want"; fail=1; fi
}
expect "plane file with no mission-brief is refused" 2 "$dir/none.jsonl" 'bin/plane file GAME "A title" --body-file b.md'
expect "tea issues create with no mission-brief is refused" 2 "$dir/none.jsonl" 'tea issues create --title T </dev/null'
expect "tea issue create is refused too" 2 "$dir/none.jsonl" 'tea issue create --title T </dev/null'
expect "gh issue create is refused" 2 "$dir/none.jsonl" 'gh issue create --title T --body b'
expect "a filing command after cd and && is refused" 2 "$dir/none.jsonl" 'cd repo && bin/plane file GAME T'
expect "the refusal names mission-brief and its three checks" 2 "$dir/none.jsonl" 'bin/plane file GAME T'
grep -q "mission-brief" "$dir/err" && grep -q "codebase" "$dir/err" && grep -q "tracker" "$dir/err" && echo "ok   the steer names the three checks" || { echo "FAIL the steer names the three checks"; fail=1; }
expect "plane file after mission-brief started runs" 0 "$dir/briefed.jsonl" 'bin/plane file GAME T'
expect "tea issues create after mission-brief started runs" 0 "$dir/briefed.jsonl" 'tea issues create --title T </dev/null'
expect "plane comment is no filing" 0 "$dir/none.jsonl" 'bin/plane comment GAME-12 "text"'
expect "gh issue list is no filing" 0 "$dir/none.jsonl" 'gh issue list'
expect "tea issues list is no filing" 0 "$dir/none.jsonl" 'tea issues list </dev/null'
expect "a quoted mention is no filing" 0 "$dir/none.jsonl" 'grep "plane file" notes.md'
expect "a heredoc body that names it is no filing" 0 "$dir/none.jsonl" "cat > n.md <<'EOF'
bin/plane file GAME T
EOF"
expect "the setting off lets it through" 0 "$dir/none.jsonl" 'bin/plane file GAME T' CLAUDE_PLUGIN_OPTION_GUARD_TICKET_FILING=false
expect "a missing transcript lets it through" 0 "$dir/missing.jsonl" 'bin/plane file GAME T'
echo '' | CLAUDE_PLUGIN_OPTION_GUARD_TICKET_FILING=true "$guard" >/dev/null 2>&1; [ $? = 0 ] && echo "ok   an empty payload passes" || { echo "FAIL an empty payload passes"; fail=1; }
exit $fail
