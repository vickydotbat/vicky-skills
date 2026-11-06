#!/usr/bin/env bash
# The step guard's decisions the approved examples leave out: a title still
# marked WIP:, a body lookup that fails, a missing transcript, a command that
# marks nothing ready, and a skip reason on Gitea.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills"
guard="$root/scripts/step-guard.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
fail=0
started() { jq -nc --arg s "$1" '{type:"assistant",message:{content:[{type:"tool_use",name:"Skill",input:{skill:$s}}]}}'; }
{ started vicky-skills:do; started vicky-skills:sentinels; } > "$dir/noreview.jsonl"
mkdir "$dir/ok" "$dir/broken"
printf '#!/bin/sh\ncat "%s/body"\n' "$dir" > "$dir/ok/gh"
printf '#!/bin/sh\njq -n --rawfile b "%s/body" "{body: \\$b}"\n' "$dir" > "$dir/ok/tea"
printf '#!/bin/sh\nexit 1\n' > "$dir/broken/gh"; cp "$dir/broken/gh" "$dir/broken/tea"
chmod +x "$dir"/ok/* "$dir"/broken/*
: > "$dir/body"
expect() { # name want bin transcript command [env...]
  local name=$1 want=$2 bin=$3 transcript=$4 cmd=$5; shift 5
  jq -nc --arg c "$cmd" --arg t "$transcript" '{tool_input:{command:$c},transcript_path:$t}' |
    env PATH="$dir/$bin:$PATH" CLAUDE_PLUGIN_OPTION_STEP_GUARD=true "$@" "$guard" >/dev/null 2>&1; got=$?
  if [ "$got" = "$want" ]; then echo "ok   $name"; else echo "FAIL $name: exit $got, want $want"; fail=1; fi
}
expect "a Gitea title still marked WIP: is no ready" 0 ok "$dir/noreview.jsonl" 'tea pr edit 12 -t "WIP: Step guard" </dev/null'
expect "a Gitea title in single quotes is read" 2 ok "$dir/noreview.jsonl" "tea pr edit 12 -t 'Step guard' </dev/null"
expect "a GitHub body lookup that fails lets it through" 0 broken "$dir/noreview.jsonl" 'gh pr ready 37'
expect "a Gitea body lookup that fails lets it through" 0 broken "$dir/noreview.jsonl" 'tea pr edit 12 -t "Step guard" </dev/null'
expect "a missing transcript lets it through" 0 ok "$dir/none.jsonl" 'gh pr ready 37'
expect "a command that marks nothing ready runs" 0 ok "$dir/noreview.jsonl" 'git status'
expect "a forge variable left in the environment changes nothing" 0 ok "$dir/noreview.jsonl" 'git status' forge=gh
mkdir "$dir/garbled"; printf '#!/bin/sh\necho not json\n' > "$dir/garbled/tea"; chmod +x "$dir/garbled/tea"
expect "a Gitea answer that isn't JSON lets it through" 0 garbled "$dir/noreview.jsonl" 'tea pr edit 12 -t "Step guard" </dev/null'
printf 'Skipped: review, because the diff is one typo\nPlan check: none found\n' > "$dir/body"
expect "a skip reason on Gitea lets it through" 0 ok "$dir/noreview.jsonl" 'tea pr edit 12 -t "Step guard" </dev/null'
started vicky-skills:warp > "$dir/warponly.jsonl"
{ started vicky-skills:warp; started vicky-skills:sentinels; } > "$dir/warpsent.jsonl"
printf 'Skipped: do, because a\nSkipped: review, because c\n' > "$dir/body"
expect "a warp with no do needs no Plan check line" 0 ok "$dir/warpsent.jsonl" 'gh pr ready 37'
printf 'Skipped: do, because a\nSkipped: sentinels, because b\nSkipped: review, because c\n' > "$dir/body"
expect "a warp that never ran sentinels is refused whatever its body says" 2 ok "$dir/warponly.jsonl" 'gh pr ready 37'
printf 'Skipped: review, because c\nPlan check: none found\n' > "$dir/body"
expect "a warp that ran sentinels and skipped review is still refused for do" 2 ok "$dir/warpsent.jsonl" 'gh pr ready 37'
says() { # name transcript present-text absent-text: what the refusal says
  local err
  err=$(jq -nc --arg c 'gh pr ready 37' --arg t "$2" '{tool_input:{command:$c},transcript_path:$t}' |
    PATH="$dir/ok:$PATH" CLAUDE_PLUGIN_OPTION_STEP_GUARD=true "$guard" 2>&1 >/dev/null)
  if grep -qF -- "$3" <<<"$err" && { [ -z "${4:-}" ] || ! grep -qF -- "$4" <<<"$err"; }; then echo "ok   $1"; else echo "FAIL $1: $err"; fail=1; fi
}
printf 'Plan check: none found\n' > "$dir/body"
says "a missing review is told it can be skipped in writing, and sentinels is not mentioned as never skipped" "$dir/noreview.jsonl" "Skipped: <step>, because" "never skipped"
printf 'Skipped: review, because c\nPlan check: none found\n' > "$dir/body"
says "a warp that ran nothing is told that its do and sentinels steps never ran" "$dir/warponly.jsonl" "its do sentinels step"
says "a refusal reminds the agent that a warp builds each star with do, and do runs sentinels" "$dir/warponly.jsonl" "do runs sentinels on what it changed"
{ started vicky-skills:do; started vicky-skills:review; } > "$dir/nosent.jsonl"
printf 'Plan check: none found\n' > "$dir/body"
says "a missing sentinels is told it is never skipped, with its manual pass, and no written skip is offered" "$dir/nosent.jsonl" "manual pass" "Skipped: <step>, because"
# Text a shell runs is code, so it is read; text that only names the command is not.
expect "a bash -c string is read" 2 ok "$dir/noreview.jsonl" 'bash -c "gh pr ready 37"'
expect "an eval string is read" 2 ok "$dir/noreview.jsonl" "eval 'gh pr ready 37'"
expect "a heredoc fed to bash is read" 2 ok "$dir/noreview.jsonl" "$(printf 'bash <<EOF\ngh pr ready 37\nEOF')"
expect "a heredoc fed to cat is not read" 0 ok "$dir/noreview.jsonl" "$(printf 'cat <<EOF\ngh pr ready 37\nEOF')"
expect "the words in a single-quoted echo are not read" 0 ok "$dir/noreview.jsonl" "echo 'gh pr ready 37'"
expect "an ssh string is read" 2 ok "$dir/noreview.jsonl" 'ssh host "gh pr ready 37"'
expect "a watch string is read" 2 ok "$dir/noreview.jsonl" "watch 'gh pr ready 37'"
expect "a python -c string is read" 2 ok "$dir/noreview.jsonl" "python3 -c 'import os; os.system(\"gh pr ready 37\")'"
expect "a substitution inside double quotes is read" 2 ok "$dir/noreview.jsonl" 'echo "$(gh pr ready 37)"'
expect "a backtick substitution is read" 2 ok "$dir/noreview.jsonl" 'echo "`gh pr ready 37`"'
expect "a command with an escaped quote is read whole" 2 ok "$dir/noreview.jsonl" "echo it\\'s; gh pr ready 37; echo 'x'"
expect "one shell string anywhere turns the stripping off, and the command is refused" 2 ok "$dir/noreview.jsonl" 'bash -c "ls" && gh pr comment 37 --body "gh pr ready"'
exit $fail
