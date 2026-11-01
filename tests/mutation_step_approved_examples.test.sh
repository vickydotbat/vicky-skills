#!/usr/bin/env bash
# approved-spec: the examples approved for "warp reaches do, and do reaches
# sentinels". Each check is named after its example.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills"
guard="$root/scripts/step-guard.sh"; hint="$root/scripts/step-hint.sh"
dir=$(mktemp -d); trap 'rm -rf "$dir"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
started() { for s; do jq -nc --arg s "$s" '{type:"assistant",message:{content:[{type:"tool_use",name:"Skill",input:{skill:$s}}]}}'; done; }
mkdir "$dir/bin"; printf '#!/bin/sh\ncat "%s/body"\n' "$dir" > "$dir/bin/gh"; chmod +x "$dir/bin/gh"
: > "$dir/body"
run() { # $1 transcript
  jq -nc --arg t "$1" '{tool_input:{command:"gh pr ready 37"},transcript_path:$t}' |
    PATH="$dir/bin:$PATH" CLAUDE_PLUGIN_OPTION_STEP_GUARD=true "$guard" 2>"$dir/err"; }

# Given a warp session that never started do
# When the agent marks its pull request ready
# Then it is refused, and the refusal names the do step
started vicky-skills:warp vicky-skills:sentinels vicky-skills:review > "$dir/nodo.jsonl"
run "$dir/nodo.jsonl"; code=$?
check "warp without do is refused" '[ $code = 2 ] && grep -q "its do step" "$dir/err"'

# Given a do build whose review ran but whose sentinels pass never started
# When the agent marks its pull request ready
# Then it is refused, and the refusal names sentinels
started vicky-skills:do vicky-skills:review > "$dir/nosentinels.jsonl"
run "$dir/nosentinels.jsonl"; code=$?
check "do without sentinels is refused" '[ $code = 2 ] && grep -q "sentinels" "$dir/err"'

# Given a do build that never started sentinels
# And a pull request body that says Skipped: sentinels, because the diff holds no decision logic
# When the agent marks its pull request ready
# Then the pull request goes ready
echo 'Skipped: sentinels, because the diff holds no decision logic' > "$dir/body"
run "$dir/nosentinels.jsonl"; code=$?
check "a written skip lets it through" '[ $code = 0 ]'
: > "$dir/body"

# Given a warp session that started do, sentinels and review
# When the agent marks its pull request ready
# Then the pull request goes ready
started vicky-skills:warp vicky-skills:do vicky-skills:sentinels vicky-skills:review > "$dir/full.jsonl"
run "$dir/full.jsonl"; code=$?
check "a full build goes ready" '[ $code = 0 ]'

# Given the step guard setting is on
# When warp starts
# Then the agent is told in one line to start do for each star, and that do runs sentinels
out=$(jq -nc '{tool_input:{skill:"vicky-skills:warp"}}' | CLAUDE_PLUGIN_OPTION_STEP_GUARD=true "$hint" | jq -r '.hookSpecificOutput.additionalContext // empty')
check "warp starts with the hint" '[ "$(wc -l <<<"$out")" = 1 ] && grep -q "do. for each star" <<<"$out" && grep -q sentinels <<<"$out"'

# Given a pull request whose How tested section has no mutation counts
# When make-it-so checks Q10
# Then it passes only on a line that says unrun, because, followed by the log line or reason
q10=$(grep 'Q10' "$root/skills/engineering/make-it-so/SKILL.md")
check "make-it-so takes no silent excuse" 'grep -q "unrun, because" <<<"$q10" && ! grep -q "or why there are none" <<<"$q10"'
exit $fail
