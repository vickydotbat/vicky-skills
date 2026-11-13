#!/usr/bin/env bash
# approved-spec: the finishing order red, green, mutate, metrics, QA, for a
# repo whose testing standards have a Metrics: line. Each check is named
# after its example and reads the instructions that drive the agent.
set -u
p="$(dirname "$0")/../plugins/vicky-skills/skills/engineering"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
step4=$(grep '^4\. ' "$p/do/SKILL.md")
q10=$(grep 'Q10' "$p/make-it-so/SKILL.md")

# Given a repo with a Metrics: line, When do has mutated the change,
# Then it reports each rule's metrics, or lists them as owed, and never gates on them
check "do runs metrics after mutation, or lists them as owed" \
  'grep -q "Metrics:" <<<"$step4" && grep -q "Metrics owed:" <<<"$step4" && grep -q "never a gate" <<<"$step4"'

# Given the same repo, When make-it-so checks Q10,
# Then it checks only that the metrics are there, never what they found
check "make-it-so checks presence, not results" \
  'grep -q "Metrics owed:" <<<"$q10" && grep -q "never what they found" <<<"$q10"'

# Given a repo without metrics, When first-contact writes its testing standards,
# Then the Metrics: line says none, and neither skill asks for metrics
check "a repo opts out with Metrics: none" \
  'grep -q "^Metrics: none" "$p/first-contact/testing-standards.md" && grep -q "isn'"'"'t \`none\`" <<<"$step4" && grep -q "isn'"'"'t \`none\`" <<<"$q10"'
exit $fail
