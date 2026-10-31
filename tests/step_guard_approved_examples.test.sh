#!/usr/bin/env bash
# approved-spec: the examples approved for "no step skipped without a provable
# reason". Each check is named after its example.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills"
guard="$root/scripts/step-guard.sh"; hint="$root/scripts/step-hint.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
# A transcript line for a Skill call, the way Claude Code writes one.
started() { jq -nc --arg s "$1" '{type:"assistant",message:{content:[{type:"tool_use",name:"Skill",input:{skill:$s}}]}}'; }
# gh is a service we don't own: the stub prints the pull request body.
mkdir "$dir/bin"; printf '#!/bin/sh\ncat "%s/body"\n' "$dir" > "$dir/bin/gh"; chmod +x "$dir/bin/gh"
: > "$dir/body"
run() { # $1 option, $2 transcript, $3 command
  jq -nc --arg c "$3" --arg t "$2" '{tool_input:{command:$c},transcript_path:$t}' |
    PATH="$dir/bin:$PATH" CLAUDE_PLUGIN_OPTION_STEP_GUARD=$1 "$guard" 2>"$dir/err"; }

started vicky-skills:do > "$dir/noreview.jsonl"
run true "$dir/noreview.jsonl" "gh pr ready 37"; code=$?
check "given a do build whose review step never ran, marking its pull request ready is refused and names the review step" \
  '[ $code = 2 ] && grep -q "review" "$dir/err"'

{ started vicky-skills:do; started vicky-skills:review; } > "$dir/reviewed.jsonl"
run true "$dir/reviewed.jsonl" "gh pr ready 37"; code=$?
check "given a do build whose review ran, the pull request goes ready" '[ $code = 0 ]'

echo 'Skipped: review, because the diff is one typo' > "$dir/body"
run true "$dir/noreview.jsonl" "gh pr ready 37"; code=$?
check "given a do build whose pull request body says Skipped: review, because <reason>, the pull request goes ready" '[ $code = 0 ]'
: > "$dir/body"

out=$(jq -nc '{tool_input:{skill:"vicky-skills:do"}}' | CLAUDE_PLUGIN_OPTION_STEP_GUARD=true "$hint")
check "given a do build starts, the agent is reminded in one line that each step needs its proof, or a written reason to skip it" \
  'jq -e ".hookSpecificOutput.additionalContext | test(\"proof\") and test(\"Skipped: <step>, because\")" <<<"$out" >/dev/null'

check "given a step skipped for a reason it can prove, the report names the step, the reason and the proof" \
  'grep -q "names the step, the reason and the proof" "$root/skills/engineering/do/SKILL.md"'

run false "$dir/noreview.jsonl" "gh pr ready 37"; code=$?
check "given the step guard setting is off, marking a pull request ready with no review is not refused" '[ $code = 0 ]'
started vicky-skills:sup > "$dir/nodo.jsonl"
run true "$dir/nodo.jsonl" "gh pr ready 37"; code=$?
check "given a session that never started do, marking a pull request ready with no review is not refused" '[ $code = 0 ]'
exit $fail
