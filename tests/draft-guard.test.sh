#!/usr/bin/env bash
# draft-guard: a pull request opens as a draft, always, and turns ready only
# in a session where make-it-so started. Every decision the hook makes.
set -u
hook="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/scripts/draft-guard.sh"
s=$(mktemp -d)
trap 'rm -rf "$s"' EXIT
git init -q "$s/repo"
git init -q "$s/off" && mkdir -p "$s/off/docs/agents" && printf 'PR drafts: off\n' >"$s/off/docs/agents/issue-tracker.md"
git init -q "$s/on" && mkdir -p "$s/on/docs/agents" && printf 'PR template: on\nPR drafts: on\n' >"$s/on/docs/agents/issue-tracker.md"
git init -q "$s/spice" && git -C "$s/spice" config spice.submit.draft true
# Transcripts: none asked, the agent started make-it-so, the user typed it,
# and one that only talks about it.
jq -nc '{type:"user",message:{role:"user",content:"open a PR"}}' >"$s/plain.jsonl"
{ cat "$s/plain.jsonl"; jq -nc '{type:"assistant",message:{content:[{type:"tool_use",name:"Skill",input:{skill:"vicky-skills:make-it-so"}}]}}'; } >"$s/agent.jsonl"
{ cat "$s/plain.jsonl"; jq -nc '{type:"user",message:{role:"user",content:"<command-message>make-it-so</command-message>\n<command-name>/make-it-so</command-name>"}}'; } >"$s/typed.jsonl"
{ cat "$s/plain.jsonl"
  jq -nc '{type:"assistant",message:{content:[{type:"tool_use",name:"Skill",input:{skill:"ship-it"}},{type:"text",text:"<command-name>/make-it-so</command-name>"}]}}'
  jq -nc '{type:"user",message:{role:"user",content:[{type:"tool_result",content:"<command-name>/make-it-so</command-name>"}]}}'; } >"$s/talk.jsonl"
fail=0
run() { # command transcript [cwd] [option]
  jq -nc --arg c "$1" --arg t "$2" --arg d "${3:-$s/repo}" '{hook_event_name:"PreToolUse",tool_name:"Bash",cwd:$d,session_id:"s1",transcript_path:$t,tool_input:{command:$c}}' |
    CLAUDE_PLUGIN_OPTION_GUARD_DRAFT="${4-true}" bash "$hook" >/dev/null 2>&1
  echo $?
}
expect() { # name want command [transcript] [cwd] [option]
  local got
  got=$(run "$3" "${4:-$s/plain.jsonl}" "${5:-}" "${6-true}")
  if [ "$got" = "$2" ]; then echo "ok   $1"; else echo "FAIL $1: exit $got, want $2"; fail=1; fi
}

# Opening: always a draft, make-it-so or not.
expect "gh pr create without --draft is refused" 2 'gh pr create --title T --body-file b.md'
expect "gh pr create without --draft is refused after make-it-so too" 2 'gh pr create --title T' "$s/agent.jsonl"
expect "gh pr create --draft goes through" 0 'gh pr create --draft --title T'
expect "gh pr create -d goes through" 0 'gh pr create -d --title T'
expect "gh pr create --draft=false is refused" 2 'gh pr create --draft=false --title T'
expect "gh pr create -d=false is refused" 2 'gh pr create -d=false --title T'
expect "tea pr create --draft=false is refused" 2 'tea pr create --draft=false -t Fix </dev/null'
expect "a --draft inside the quoted title does not count" 2 'gh pr create --title "T --draft"'
expect "tea pr create without WIP: is refused" 2 'tea pr create --title "Fix it" --description x </dev/null'
expect "tea pulls create is refused the same way" 2 'tea pulls create -t Fix </dev/null'
expect "tea pr create -d is a description, not a draft" 2 'tea pr create -t Fix -d body </dev/null'
expect "tea pr create with a WIP: title goes through" 0 'tea pr create --title "WIP: Fix it" </dev/null'
expect "a lower-case wip: title goes through" 0 "tea pr create -t 'wip: fix' </dev/null"
expect "tea pr create --draft goes through" 0 'tea pr create --draft --title "Fix it" </dev/null'
expect "an ANSI-quoted WIP: title goes through" 0 "tea pr create -t \$'WIP: fix' </dev/null"
expect "tea pr create with --title=WIP: goes through" 0 'tea pr create --title=WIP:Fix </dev/null'

# Marking ready: only after make-it-so started.
expect "gh pr ready is refused with no make-it-so" 2 'gh pr ready 5'
expect "gh pr ready goes through after the agent started make-it-so" 0 'gh pr ready 5' "$s/agent.jsonl"
expect "gh pr ready goes through after the user typed make-it-so" 0 'gh pr ready 5' "$s/typed.jsonl"
expect "talk about make-it-so is not make-it-so" 2 'gh pr ready 5' "$s/talk.jsonl"
expect "gh pr ready --undo goes through" 0 'gh pr ready 5 --undo'
expect "gh pr ready --undo=false is refused" 2 'gh pr ready 5 --undo=false'
expect "a flag before the subcommand is still read" 2 'gh -R o/r pr create --title T'
expect "a flag before pr ready is still read" 2 'gh --repo o/r pr ready 5'
expect "gs -C <dir> ss is still read" 2 'gs -C . ss'
expect "gs branch submit --draft=false is refused" 2 'gs branch submit --draft=false'
expect "tea pr edit --ready is refused with no make-it-so" 2 'tea pr edit 5 --ready </dev/null'
expect "tea pr edit --ready goes through after make-it-so" 0 'tea pr edit 5 --ready </dev/null' "$s/typed.jsonl"
expect "a title with no WIP: is refused with no make-it-so" 2 'tea pr edit 5 -t "Fix it" </dev/null'
expect "a title with no WIP: goes through after make-it-so" 0 'tea pr edit 5 -t "Fix it" </dev/null' "$s/agent.jsonl"
expect "a retitled draft keeps WIP: and goes through" 0 'tea pr edit 5 --title "WIP: Fix it better" </dev/null'
expect "a retitle with --draft goes through" 0 'tea pr edit 5 -t "Fix it" --draft </dev/null'
expect "a body edit goes through" 0 'tea pr edit 5 --description x </dev/null'
expect "a ready mark later in a chain is refused" 2 'git push && gh pr ready 5'
expect "a ready mark inside bash -c is refused" 2 'bash -c "gh pr ready 5"'
expect "a ready mark only echoed is text" 0 'echo "gh pr ready 5"'
expect "a ready mark in a heredoc body is text" 0 'cat <<EOF >note
gh pr ready 5
EOF'

# Stacks.
expect "gh stack submit without --auto is refused" 2 'gh stack submit'
expect "gh stack submit --auto goes through" 0 'gh stack submit --auto'
expect "gh stack submit --auto --open is refused" 2 'gh stack submit --auto --open'
expect "gh stack submit --open goes through after make-it-so" 0 'gh stack submit --auto --open' "$s/agent.jsonl"
expect "gs stack submit without --draft is refused" 2 'gs stack submit -l stacked'
expect "gs ss without --draft is refused" 2 'gs ss'
expect "gs stack submit --draft goes through" 0 'gs stack submit --draft -l stacked'
expect "gs submit goes through where spice.submit.draft is true" 0 'gs stack submit' "" "$s/spice"
expect "gs submit --no-draft is refused" 2 'gs stack submit --draft --no-draft'
expect "gs submit --no-draft goes through after make-it-so" 0 'gs bs --no-draft' "$s/agent.jsonl"

# What passes untouched.
expect "a --help call goes through" 0 'tea pr create --help </dev/null'
expect "gh pr create --help goes through" 0 'gh pr create --help'
expect "other forge commands go through" 0 'gh pr view 5 --comments && tea pr 5 --comments </dev/null'
expect "a command with no forge CLI goes through" 0 'git status'
expect "a missing transcript lets a ready mark through" 0 'gh pr ready 5' "$s/none.jsonl"
expect "the option off lets everything through" 0 'gh pr create --title T' "" "" false
expect "the option at 0 lets everything through" 0 'gh pr ready 5' "" "" 0
expect "a repo with PR drafts: off lets everything through" 0 'gh pr create --title T' "" "$s/off"
expect "a repo with PR drafts: on is guarded" 2 'gh pr create --title T' "" "$s/on"
expect "an unclosed quote is read whole, and its ready mark refused" 2 'echo "x; gh pr ready 5'
expect "a leading cd elsewhere still judges the command" 2 "cd $s/repo && gh pr ready 5"
got=$(printf '{bad json' | CLAUDE_PLUGIN_OPTION_GUARD_DRAFT=true bash "$hook" >/dev/null 2>&1; echo $?)
if [ "$got" = 0 ]; then echo "ok   bad input goes through"; else echo "FAIL bad input goes through: exit $got"; fail=1; fi

# The refusal steers, and hands no command to the user.
msg=$(jq -nc --arg t "$s/plain.jsonl" --arg d "$s/repo" '{cwd:$d,transcript_path:$t,tool_input:{command:"gh pr ready 5"}}' | bash "$hook" 2>&1 >/dev/null)
if grep -q 'leave it a draft' <<<"$msg" && grep -q make-it-so <<<"$msg"; then echo "ok   the ready refusal says to leave it a draft"; else echo "FAIL the ready refusal: $msg"; fail=1; fi
exit $fail
