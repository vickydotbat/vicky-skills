#!/usr/bin/env bash
# The hook refuses a rebase onto a moved default branch until history-monks starts.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
hook="$root/plugins/vicky-skills/scripts/rebase-guard.sh"
s=$(mktemp -d); trap 'rm -rf "$s"' EXIT
fail=0
gi() { git -C "$1" -c user.email=t@t -c user.name=t -c commit.gpgsign=false "${@:2}"; }
run() { # command transcript cwd option
  jq -nc --arg c "$1" --arg t "$2" --arg d "$3" '{cwd:$d,transcript_path:$t,tool_input:{command:$c}}' |
    CLAUDE_PLUGIN_OPTION_GUARD_REBASE=${4:-true} bash "$hook" >/dev/null 2>&1; echo $?
}
expect() { # name want command [transcript] [cwd] [option]
  local got; got=$(run "$3" "${4:-$s/plain.jsonl}" "${5:-$s/work}" "${6:-true}")
  if [ "$got" = "$2" ]; then echo "ok   $1"; else echo "FAIL $1: want $2, got $got"; fail=1; fi
}
echo '{"type":"user","message":{"content":"rebase it"}}' >"$s/plain.jsonl"
jq -nc '{type:"assistant",message:{content:[{type:"tool_use",name:"Skill",input:{skill:"vicky-skills:history-monks"}}]}}' >"$s/monks.jsonl"
jq -nc '{type:"user",message:{content:"<command-name>/vicky-skills:history-monks</command-name>"}}' >"$s/typed.jsonl"
jq -nc '{type:"user",message:{content:[{type:"tool_result",content:"<command-name>/history-monks</command-name>"}]}}' >"$s/quoted.jsonl"

git init -q --bare -b main "$s/rem"
git clone -q "$s/rem" "$s/seed" 2>/dev/null
gi "$s/seed" checkout -q -b main 2>/dev/null; gi "$s/seed" commit -q --allow-empty -m one; gi "$s/seed" push -q origin main
git clone -q "$s/rem" "$s/work" 2>/dev/null
gi "$s/work" checkout -q -b topic; gi "$s/work" commit -q --allow-empty -m topic
gi "$s/work" branch parent

expect "current branch: a rebase passes" 0 'git rebase origin/main'
gi "$s/seed" commit -q --allow-empty -m two; gi "$s/seed" push -q origin main
# The hook fetches, so the work clone's origin/main is stale on purpose.
expect "moved main: rebase onto origin/main is refused" 2 'git rebase origin/main'
expect "moved main: rebase onto main is refused" 2 'git rebase main'
expect "the audited form is refused" 2 'git fetch -q && git rebase -q origin/main && git log --oneline -3'
expect "rebase --onto main is refused" 2 'git rebase --onto origin/main parent topic'
expect "rebase --onto=main is refused" 2 'git rebase --onto=origin/main parent'
expect "a strategy option before main is refused" 2 'git rebase -X theirs origin/main'
expect "a strategy before main is refused" 2 'git rebase -s ort origin/main'
expect "an exec command before main is refused" 2 'git rebase --exec make origin/main'
expect "a strategy option before a stack parent passes" 0 'git rebase -X theirs parent'
expect "via cd is refused" 2 "cd $s/work && git rebase origin/main" "$s/plain.jsonl" "$s"
expect "a typed history-monks lets it through" 0 'git rebase origin/main' "$s/typed.jsonl"
expect "a started history-monks lets it through" 0 'git rebase origin/main' "$s/monks.jsonl"
expect "a quoted marker in a tool result does not count" 2 'git rebase origin/main' "$s/quoted.jsonl"
expect "--continue passes" 0 'git rebase --continue'
expect "--abort passes" 0 'git rebase --abort'
expect "--skip passes" 0 'git rebase --skip'
expect "a stack parent passes" 0 'git rebase parent'
expect "onto a stack parent from main passes" 0 'git rebase --onto parent origin/main topic'
expect "--continue after the refused form passes" 0 'git rebase --continue && git log -1'
expect "git pull --rebase passes" 0 'git pull --rebase'
expect "a quoted mention passes" 0 'echo "git rebase origin/main"'
expect "the option off passes" 0 'git rebase origin/main' "$s/plain.jsonl" "$s/work" false
expect "the option at 0 passes" 0 'git rebase origin/main' "$s/plain.jsonl" "$s/work" 0
expect "a missing transcript passes" 0 'git rebase origin/main' "$s/none.jsonl"
expect "outside a repo passes" 0 'git rebase origin/main' "$s/plain.jsonl" "$s"
gi "$s/work" checkout -q main
expect "on the default branch passes" 0 'git rebase origin/main'
gi "$s/work" checkout -q topic
gi "$s/work" fetch -q; gi "$s/work" rebase -q origin/main
expect "after a rebase that took main's tip, it passes" 0 'git rebase origin/main'
gi "$s/work" remote set-head origin -d 2>/dev/null; gi "$s/work" update-ref -d refs/remotes/origin/main
expect "no known default branch passes" 0 'git rebase main'

gi "$s/seed" checkout -q -b side HEAD~1
msg=$(jq -nc --arg t "$s/plain.jsonl" --arg d "$s/seed" '{cwd:$d,transcript_path:$t,tool_input:{command:"git rebase origin/main"}}' | bash "$hook" 2>&1 >/dev/null)
if grep -q 'history-monks' <<<"$msg" && grep -q 'Disjoint' <<<"$msg"; then echo "ok   the refusal steers to history-monks"; else echo "FAIL the refusal steers to history-monks: $msg"; fail=1; fi
exit $fail
