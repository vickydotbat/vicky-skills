#!/usr/bin/env bash
# approved-spec: the examples approved for "sentinels mutates law proofs
# first". The checks read the sentinels text that drives the agent; the reach
# mode it names is proven by tests/laws_line_approved_examples.test.sh.
set -u
s="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/skills/building/sentinels/SKILL.md"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

check "given a diff whose changed code a law's proof covers, when sentinels runs a mutation pass, then the code under that proof is mutated first, and a proof that kills no mutant is reported as a proof that cannot fail" \
  'grep -q "law-lint.sh reach" "$s" && grep -q "mutate them first" "$s" && grep -q "cannot fail (killed 0)" "$s"'

check "given changed files, some reached by a law's proof, when sentinels narrows the target, then it lists them with law-lint.sh reach and mutates them first, and a skill-text proof gets a manual mutant deleting the phrase its grep matches" \
  'grep -q "law-lint.sh reach <base>" "$s" && grep -q "delete the phrase its grep matches" "$s"'

check "given a law's proof, when sentinels writes its report, then it adds a cannot-fail line when the proof killed no mutant, and a can-fail line otherwise" \
  'grep -q -- "- law <file:line>: proof <check> cannot fail (killed 0)" "$s" && grep -q "proof can fail (killed <n>)" "$s"'
exit $fail
