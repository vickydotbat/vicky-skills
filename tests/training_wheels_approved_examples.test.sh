#!/usr/bin/env bash
# approved-spec: the examples the user set during the Todo list warp: user
# prompts are training wheels. Reads the instructions that drive the agent.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
log="$root/plugins/vicky-skills/skills/engineering/captains-log/SKILL.md"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
step() { awk -v n="$1" '$0 ~ "^"n"\\. "{on=1; print; next} /^[0-9]+\. /{on=0} /^## /{on=0} on' "$log"; }
check "captains-log on a session where I answered permission prompts makes each prompt a finding, with the hook or context that would steer the agent so it never comes" \
  'step 3 | grep -q "\*\*Prompts\*\*" && step 3 | grep -q "each permission prompt the user answered" && step 3 | grep -q "so the prompt never comes"'
check "a hook that would ask me is the last resort, marked as training wheels, with what would replace it" \
  'sed -n "/^## Add or change a hook/,/^## /p" "$root/AGENTS.md" | grep -q "training wheels" && sed -n "/^## Add or change a hook/,/^## /p" "$root/AGENTS.md" | grep -q "what would replace it"'
exit $fail
