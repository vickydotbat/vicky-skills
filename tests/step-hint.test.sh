#!/usr/bin/env bash
# step-hint sends new player-facing text to red-pen when do, over-to-you or
# make-it-so starts, and stays quiet for other skills and when switched off.
set -u
hook="$(dirname "$0")/../plugins/vicky-skills/scripts/step-hint.sh"
fail=0
hint() { jq -nc --arg s "$1" '{tool_input:{skill:$s}}' | CLAUDE_PLUGIN_OPTION_STEP_GUARD="${2-true}" bash "$hook" | jq -r '.hookSpecificOutput.additionalContext // empty'; }
has() { if grep -qF -- "$3" <<<"$(hint "$2")"; then echo "ok   $1"; else echo "FAIL $1: '$(hint "$2")'"; fail=1; fi; }
has "do sends player text to the draft file as it is written" vicky-skills:do "red-pen draft file"
has "over-to-you refuses wording as a checklist item" vicky-skills:over-to-you "never an over-to-you item"
has "over-to-you opens the draft file before the sitting" over-to-you "before this sitting"
has "make-it-so checks player text went through the draft file" vicky-skills:make-it-so "red-pen draft file"
has "do keeps its proof hint" do "ends with its proof"
for s in vicky-skills:sup review; do
  [ -z "$(hint "$s")" ] && echo "ok   no hint for $s" || { echo "FAIL hint for $s"; fail=1; }
done
[ -z "$(hint vicky-skills:over-to-you false)" ] && echo "ok   off when the option is off" || { echo "FAIL hint while off"; fail=1; }
exit $fail
