#!/usr/bin/env bash
# approved-spec: the examples approved for "sup counts the lessons engraved".
# Each check is named after its example, and reads the instructions that drive
# the agent.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/skills"
engrave="$root/engineering/engrave/SKILL.md"; sup="$root/productivity/sup/SKILL.md"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
check "given the agent builds the rule for a lesson, when it commits the rule, then the commit message ends with an Engraved line naming the snag" \
  'grep -q "the commit message ends with \`Engraved: <snag>\`" "$engrave"'
check "given the agent engraved two lessons since my last message, in this repo or another, when I ask sup, then the catch-up says two lessons were engraved, each with its snag" \
  'grep -q "lesson-ledger.sh since" "$sup" && ! grep -q "git log --since" "$sup" && grep -q "Lessons" "$sup" && grep -q "each with its snag" "$sup"'
exit $fail
