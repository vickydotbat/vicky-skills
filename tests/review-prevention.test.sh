#!/usr/bin/env bash
# A fixed review finding gets a prevention verdict: step-hint says so when
# deathmatch starts, and deathmatch and make-it-so's settling hold the line.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
hint=$(jq -nc '{tool_input:{skill:"vicky-skills:deathmatch"}}' | CLAUDE_PLUGIN_OPTION_STEP_GUARD=true bash "$root/scripts/step-hint.sh" | jq -r '.hookSpecificOutput.additionalContext')
check "deathmatch's start asks for a prevention verdict" 'grep -qF "also gets a prevention verdict" <<<"$hint"'
off=$(jq -nc '{tool_input:{skill:"deathmatch"}}' | CLAUDE_PLUGIN_OPTION_STEP_GUARD=false bash "$root/scripts/step-hint.sh")
check "with step_guard off, no hint" '[ -z "$off" ]'
exit $fail
