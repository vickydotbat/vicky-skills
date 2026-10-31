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
started vicky-skills:do > "$dir/noreview.jsonl"
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
echo 'Skipped: review, because the diff is one typo' > "$dir/body"
expect "a skip reason on Gitea lets it through" 0 ok "$dir/noreview.jsonl" 'tea pr edit 12 -t "Step guard" </dev/null'
exit $fail
