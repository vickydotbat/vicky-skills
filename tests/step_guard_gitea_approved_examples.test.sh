#!/usr/bin/env bash
# approved-spec: the examples approved for the step guard on Gitea (G1, G2).
# Each check is named after its example.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills"
guard="$root/scripts/step-guard.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
started() { jq -nc --arg s "$1" '{type:"assistant",message:{content:[{type:"tool_use",name:"Skill",input:{skill:$s}}]}}'; }
# tea is a service we don't own: the stub answers `tea pr <n> --output json` with the body.
mkdir "$dir/bin"
printf '#!/bin/sh\njq -n --rawfile b "%s/body" "{body: \\$b}"\n' "$dir" > "$dir/bin/tea"; chmod +x "$dir/bin/tea"
: > "$dir/body"
run() { # transcript command
  jq -nc --arg c "$2" --arg t "$1" '{tool_input:{command:$c},transcript_path:$t}' |
    PATH="$dir/bin:$PATH" CLAUDE_PLUGIN_OPTION_STEP_GUARD=true "$guard" 2>"$dir/err"; }

{ started vicky-skills:do; started vicky-skills:sentinels; } > "$dir/noreview.jsonl"
run "$dir/noreview.jsonl" 'tea pr edit 12 -t "Step guard on Gitea" </dev/null'; code=$?
check "given a do build on Gitea whose review never ran, dropping WIP: from its pull request title is refused and names the review step" \
  '[ $code = 2 ] && grep -q "review" "$dir/err"'

{ started vicky-skills:do; started vicky-skills:sentinels; started vicky-skills:review; } > "$dir/reviewed.jsonl"
run "$dir/reviewed.jsonl" 'tea pr edit 12 -t "Step guard on Gitea" </dev/null'; code=$?
check "given a do build on Gitea whose sentinels and review ran, dropping WIP: from its pull request title changes the title" '[ $code = 0 ]'
exit $fail
