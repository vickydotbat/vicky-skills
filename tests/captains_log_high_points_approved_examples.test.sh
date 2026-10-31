#!/usr/bin/env bash
# approved-spec: the examples approved on the star "captains-log finds high
# points". Each check is named after its example. The behaviour is the
# agent's, so each check reads the instruction that drives it.
set -u
skills="$(dirname "$0")/../plugins/vicky-skills/skills"
log="$skills/engineering/captains-log/SKILL.md"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
# Prints the numbered step whose bold name starts with $1, up to the next step.
step() { awk -v n="$1" '/^[0-9]+\. /{on = index($0, "**" n) > 0} on' "$log"; }
high=$(step "Find the high points")

check "a session where I said a result was exactly what I wanted is named a high point, with the agent-file line that caused it" \
  'grep -q "Find the high points" <<<"$high" && grep -q "exactly what they wanted" <<<"$high" && grep -q "line in an agent file, skill or doc that caused it" <<<"$high" && step "Read the session" | grep -q "exceptionally well"'
check "a session where nothing went better than usual gets \"no high point found\"" \
  'grep -q "No high point found" <<<"$high"'
check "a line in AGENTS.md named as a high point's cause gets a kept mark beside it, with the date and the reason" \
  'grep -qF "add \` <!-- kept YYYY-MM-DD: <why> -->\` at its end" <<<"$high"'
check "a later captains-log or robot-voice pass looking for lines that change nothing leaves a kept line alone" \
  'step "Find candidates" | grep "change nothing" | grep -qF "<!-- kept" && grep "Delete each one" "$skills/productivity/robot-voice/SKILL.md" | grep -qF "<!-- kept"'
check "once captains-log finds a high point, cerebro gets it and proposes how to get more of it" \
  'step "Hand the trends" | grep -q "cerebro" && step "Hand the trends" | grep -q "the high points from step" && step "Hand the trends" | grep -q "get more of each high point"'
exit $fail
