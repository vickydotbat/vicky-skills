#!/usr/bin/env bash
# approved-spec: the examples approved for "engrave refuses a law with no
# proof". Each check reads the engrave text that drives the agent.
set -u
s="$(cd "$(dirname "$0")/.." && pwd)/plugins/vicky-skills/skills/shipping/engrave/SKILL.md"
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

check "given a snag whose law is a skill line, when engrave writes the law, then the line names its proof: an eval case, a check or a hook, and engrave stops if it can name none, saying the law is only a wish" \
  'grep -q "names its proof: an eval case, a check or a hook" "$s" && grep -q "the law is only a wish" "$s"'

check "given a law that is a check or a hook with its own test, when engrave writes it, then the test is its proof and nothing more is added" \
  'grep -q "its own test is its proof, and nothing more is added" "$s" && ! grep -q "needs no case" "$s"'

check "given engrave writes a law, when the law is written, then the line after it reads Proven by: <check>, a repo-relative path to the test, the hook test or the eval case folder" \
  'grep -q "the line after it reads \`Proven by: <check>\`" "$s" && grep -q "repo-relative path" "$s"'

check "given a skill-line law in a repo with no evals folder and no check that can hold it, when engrave writes the law, then it stops and never names an eval case path that does not exist" \
  'grep -q "never names an eval case path that does not exist" "$s"'

check "given a law routed to another repo or session, when engrave reports it, then its Proven by line names the proof in that destination, and until that proof is built the report calls it unproven, never engraved" \
  'grep -q "names the proof in that destination" "$s" && grep -q "📓 Unproven:" "$s"'
exit $fail
