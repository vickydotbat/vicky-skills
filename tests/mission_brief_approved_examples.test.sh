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
check "typing /mission-brief after a conversation settled a feature writes the spec from that conversation and opens it in my editor before anything is filed" \
  'grep -q "^disable-model-invocation: true" "$s" && step 1 | grep -q "from the conversation" && step 2 | grep -q "red-pen" && step 2 | grep -q "before anything is filed"'
check "once I close the spec, mission-brief files it as a star chart in the repo tracker, one star per slice, each with Given / When / Then examples drafted with examples" \
  'step 3 | grep -q "star chart" && step 3 | grep -q "one star per slice" && step 3 | grep -q "\`examples\`"'
check "a slice whose examples I cut in the editor is filed with \"Examples: not written yet\", never with examples I didn't see" \
  'grep -q "Examples: not written yet" "$s" && grep -q "never with examples the user did not see" "$s"'
check "an agent that decides a conversation needs tickets asks me to type /mission-brief and never starts it" \
  'grep -q "type \`/mission-brief\`" "$root/plugins/vicky-skills/skills/engineering/do/SKILL.md"'
check "the README thanks Matt Pocock's to-spec and to-tickets for the idea" \
  'grep -q "to-spec" "$root/README.md" && grep -q "to-tickets" "$root/README.md" && grep "to-tickets" "$root/README.md" | grep -q "mission-brief"'
exit $fail
