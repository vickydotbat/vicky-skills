#!/usr/bin/env bash
# approved-spec: the examples approved on the star "Captains log and cerebro
# friction pass, then PR". Each check is named after its example. The
# behaviour is the agent's, so each check reads the instruction that drives it.
set -u
skills="$(dirname "$0")/../plugins/vicky-skills/skills"
cerebro="$skills/productivity/cerebro/SKILL.md"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
step() { awk -v n="$2" '$0 ~ "^"n"\\. "{on=1; print; next} /^[0-9]+\. /{on=0} /^## /{on=0} on' "$1"; }
ask=$(grep -A3 'Ask as the user' "$cerebro")

check "cerebro lists, under each proposal, the questions I'd ask about it, and folds each answer into that proposal or the ticket it files" \
  'grep -q "^[0-9]\. \*\*Ask as the user" "$cerebro" && grep -q "questions the user would ask about it" <<<"$ask" && grep -q "into that proposal or the ticket it files" <<<"$ask" && [ "$(grep -n "Ask as the user" "$cerebro" | cut -d: -f1)" -gt "$(grep -n "Forecast the next asks" "$cerebro" | cut -d: -f1)" ]'
check "a proposal that raises no question I'd ask stands alone, with no empty question list" \
  'grep -q "no empty question list" <<<"$ask"'
check "review runs cerebro as a forecast on what it found, once its report ends mid-effort" \
  'step "$skills/engineering/review/SKILL.md" 5 | grep -q "run \`cerebro\` as a forecast on the findings"'
check "a design decision recorded mid-effort, an anomaly answered or a council ended, runs cerebro as a forecast on what it makes due" \
  'step "$skills/engineering/lay-course/SKILL.md" 4 | grep -q "run \`cerebro\` as a forecast on what the decision makes due" && step "$skills/productivity/council-of-elrond/SKILL.md" 5 | grep -q "run \`cerebro\` as a forecast on what the decision makes due"'
exit $fail
