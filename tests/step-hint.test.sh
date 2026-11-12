#!/usr/bin/env bash
# step-hint sends new player-facing text to red-pen when do, over-to-you or
# make-it-so starts, keeps a council in its seats until Frodo speaks, and stays quiet for other skills and when switched off.
set -u
hook="$(dirname "$0")/../plugins/vicky-skills/scripts/step-hint.sh"
fail=0
hint() { jq -nc --arg s "$1" '{tool_input:{skill:$s}}' | CLAUDE_PLUGIN_OPTION_STEP_GUARD="${2-true}" bash "$hook" | jq -r '.hookSpecificOutput.additionalContext // empty'; }
has() { if grep -qF -- "$3" <<<"$(hint "$2")"; then echo "ok   $1"; else echo "FAIL $1: '$(hint "$2")'"; fail=1; fi; }
has "do sends player text to the draft file as it is written" vicky-skills:do "red-pen draft file"
has "over-to-you refuses wording as a checklist item" vicky-skills:over-to-you "never an over-to-you item"
has "over-to-you opens the draft file before the sitting" over-to-you "before this sitting"
has "over-to-you puts the branch in the clone itself" over-to-you "switch the clone to it"
has "make-it-so checks player text went through the draft file" vicky-skills:make-it-so "red-pen draft file"
has "do keeps its proof hint" do "ends with its proof"
has "sentinels writes its estimate before a pass" sentinels "write its estimate"
has "do reads a star's chart first" do "read the chart whole first"
for s in do warp examples away-team vicky-skills:lay-course; do has "$s reads the repo's docs first" "$s" "Read the repo's docs on what you touch"; done
has "away-team gets only the docs line" away-team "corrected before it reaches a ticket, a comment or code."
[ "$(hint away-team | tail -c 6)" = "code." ] && echo "ok   away-team hint ends at the docs line" || { echo "FAIL away-team hint has a trailing part"; fail=1; }
has "review gets no docs line" review "prevention verdict"
hint review | grep -q "repo's docs" && { echo "FAIL review got the docs line"; fail=1; }
has "warp reads the chart's Prime directive first" warp "Prime directive binds every star"
has "a council keeps every line in the seats until Frodo speaks" vicky-skills:council-of-elrond "every line the user sees comes from a seat"
has "after Frodo, the council writes plain prose" council-of-elrond "write plain prose from then on"
# E13, a plain regression test: no familiar_kind setting exists yet, so the
# plan check could not differ by kind before it was built.
# Given any familiar kind set, or no familiar at all
# When do builds
# Then the plan check runs the same, and only the voice of its report changes
plain=$(hint do)
for kind in owl imp raven; do
  same=$(jq -nc '{tool_input:{skill:"do"}}' | CLAUDE_PLUGIN_OPTION_FAMILIAR_KIND=$kind CLAUDE_PLUGIN_OPTION_STEP_GUARD=true bash "$hook" | jq -r '.hookSpecificOutput.additionalContext')
  [ "$same" = "$plain" ] && echo "ok   E13 the plan check is the same for the $kind" || { echo "FAIL E13 the plan check differs for the $kind"; fail=1; }
done
for s in vicky-skills:sup; do
  [ -z "$(hint "$s")" ] && echo "ok   no hint for $s" || { echo "FAIL hint for $s"; fail=1; }
done
[ -z "$(hint vicky-skills:over-to-you false)" ] && echo "ok   off when the option is off" || { echo "FAIL hint while off"; fail=1; }
# Every skill the script speaks at is named in the README's Step hints row, so the row can't drift from the script.
row=$(grep -F '| **Step hints**' "$(dirname "$0")/../README.md")
for s in $(sed -n 's/^  \([a-z|-]*\)).*/\1/p' "$(dirname "$0")/../plugins/vicky-skills/scripts/step-hint.sh" | tr '|' '\n' | grep -v '^\*$'); do
  grep -qF "\`$s\`" <<<"$row" && echo "ok   the README row names $s" || { echo "FAIL the README row leaves out $s"; fail=1; }
done
exit $fail
