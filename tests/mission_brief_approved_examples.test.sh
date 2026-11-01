#!/usr/bin/env bash
# approved-spec: the examples approved on the star "A typed-only skill files
# tickets from a spec". Each check is named after its example. The behaviour
# is the agent's, so each check reads the instruction that drives it.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
s="$root/plugins/vicky-skills/skills/engineering/mission-brief/SKILL.md"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
step() { awk -v n="$1" '$0 ~ "^"n"\\. "{on=1; print; next} /^[0-9]+\. /{on=0} /^## /{on=0} on' "$s" 2>/dev/null; }
check "asking to file tickets after a conversation settled a feature, or typing /mission-brief, writes the spec from that conversation and opens its examples in my browser for approval before anything is filed" \
  '! grep -q "^disable-model-invocation: true" "$s" && grep -q "^description: \"File tickets" "$s" && step 1 | grep -q "from the conversation" && step 2 | grep -q "red-pen" && step 2 | grep -q "before anything is filed" && step 2 | grep -q "The spec stays out of the page"'
check "once I close the spec, mission-brief files it as a star chart in the repo tracker, one star per slice, each with Given / When / Then examples drafted with examples" \
  'step 3 | grep -q "star chart" && step 3 | grep -q "one star per slice" && step 3 | grep -q "\`examples\`"'
check "a slice whose examples I cut in the editor is filed with \"Examples: not written yet\", never with examples I didn't see" \
  'grep -q "Examples: not written yet" "$s" && grep -q "never with examples the user did not see" "$s"'
check "an agent that decides a conversation needs tickets, or is asked to convert tickets from another tool, runs mission-brief itself, and nothing is filed before I read it" \
  'grep -q "run \`mission-brief\`" "$root/plugins/vicky-skills/skills/engineering/do/SKILL.md" && grep -q "convert or import tickets made by another tool" "$s" && grep -q "re-slice them, never copy them across" "$s"'
check "the README thanks Matt Pocock's to-spec and to-tickets for the idea" \
  'grep -q "to-spec" "$root/README.md" && grep -q "to-tickets" "$root/README.md" && grep "to-tickets" "$root/README.md" | grep -q "mission-brief"'
exit $fail
