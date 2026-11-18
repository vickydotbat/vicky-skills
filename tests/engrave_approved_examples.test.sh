#!/usr/bin/env bash
# approved-spec: the examples approved for "agents codify a lesson without being
# asked". Each check is named after its example. The hint is run as a hook.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills"
hint="$root/scripts/lesson-hint.sh"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
say() { jq -nc --arg p "$2" '{hook_event_name:"UserPromptSubmit",prompt:$p}' | CLAUDE_PLUGIN_OPTION_LESSON_HINT=$1 "$hint" 2>/dev/null; }

out=$(for p in "Codify that in the skills" "Note this as a lesson in the workbench" "For the future, sit at the gate" "From now on, hooks first"; do say true "$p"; echo; done)
check "given the lesson hint is on, when my message says codify that, note this as a lesson, for the future or from now on, then the agent engraves the lesson before its next reply, and the reply names the law it built and the file it went in" \
  '[ "$(grep -c "engrave" <<<"$out")" = 4 ] && grep -q "before your reply" <<<"$out"'

check "given the lesson hint is on, when my message holds none of those phrases, then the agent gets no lesson hint" \
  '[ -x "$hint" ] && [ -z "$(say true "Make it so and merge it when done")" ]'

check "given the lesson hint is off, when my message says codify that, then the agent gets no lesson hint" \
  '[ -x "$hint" ] && [ -z "$(say false "Codify that")" ]'
exit $fail
