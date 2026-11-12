#!/usr/bin/env bash
# approved-spec: the examples approved for "sentinels is never skipped by hand".
# Each check is named after its example.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills"
first="$root/scripts/sentinels-first-guard.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
# A transcript line for a Skill call, the way Claude Code writes one.
started() { jq -nc --arg s "$1" '{type:"assistant",message:{content:[{type:"tool_use",name:"Skill",input:{skill:$s}}]}}'; }
runs() { # $1 transcript, $2 command: leaves $out empty when the command runs
  out=$(jq -nc --arg c "$2" --arg t "$1" '{tool_name:"Bash",tool_input:{command:$c},transcript_path:$t}' |
    CLAUDE_PLUGIN_OPTION_GUARD_SENTINELS_FIRST=true bash "$first")
}
: > "$dir/none.jsonl"
{ started vicky-skills:sentinels; } > "$dir/sent.jsonl"

# Given a build session that never started sentinels
# When it runs a script named for mutation (a mutate or mutant script, in python, bash or node) that it wrote itself
# Then it is refused and told to start sentinels first
runs "$dir/none.jsonl" "python3 -I $dir/mutate_loop.py"; a="$out"
runs "$dir/none.jsonl" "bash $dir/run-mutants.sh"; b="$out"
runs "$dir/none.jsonl" "node $dir/mutants.js"; c="$out"
check "E4 with a build session that never started sentinels, running a mutate or mutant script of its own in python, bash or node is refused and told to start sentinels first" \
  '[ "$(jq -r .hookSpecificOutput.permissionDecision <<<"$a")" = deny ] && [ "$(jq -r .hookSpecificOutput.permissionDecision <<<"$b")" = deny ] && [ "$(jq -r .hookSpecificOutput.permissionDecision <<<"$c")" = deny ] && grep -q "sentinels" <<<"$a"'

# Given a build session that started sentinels
# When it runs the same script
# Then it runs
runs "$dir/sent.jsonl" "python3 -I $dir/mutate_loop.py"
check "E5 with a build session that started sentinels, running the same script runs" '[ -z "$out" ]'

# Given a build session that never started sentinels
# When it greps or prints a file whose name says mutation, with the name inside quotes
# Then it runs
runs "$dir/none.jsonl" "grep -n \"mutate_loop.py\" README.md"
check "E6 with a build session that never started sentinels, grepping or printing a file whose name says mutation, with the name inside quotes, runs" '[ -z "$out" ]'
exit $fail
