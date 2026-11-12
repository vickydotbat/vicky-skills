#!/usr/bin/env bash
# approved-spec: the examples approved for "warp reaches do, and do reaches
# sentinels". Each check is named after its example.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills"
hint="$root/scripts/step-hint.sh"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
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
