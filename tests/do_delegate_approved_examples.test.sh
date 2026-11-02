#!/usr/bin/env bash
# approved-spec: the example approved for when do hands a slice to a
# subagent. It reads the do skill, since the agent follows its text.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
skill="$root/plugins/vicky-skills/skills/engineering/do/SKILL.md"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

# Given an agent running do on a large build
# When it weighs handing a slice to a subagent
# Then do tells it to hand one over only when one number or one artifact checks the result: a census, a passing filter, a filed ticket key
check "do hands a slice to a subagent only when one number or one artifact checks the result" \
  'grep -q "subagent only when one number or one artifact checks its result" "$skill" && grep -q "a census, a passing filter, a filed ticket key" "$skill"'
exit $fail
